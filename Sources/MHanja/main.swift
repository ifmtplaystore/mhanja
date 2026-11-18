import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = KeyMonitor()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private let defaults = UserDefaults.standard
    private var running = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        monitor.trigger = TriggerKey(rawValue: defaults.string(forKey: "trigger") ?? "") ?? .rightOption

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.image
        rebuildMenu()

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        NSLog("MHanja: 손쉬운 사용 권한 = \(trusted)")
        if trusted, startMonitor() { return }
        // 권한이 허용될 때까지 기다렸다가 시작
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            guard let self, AXIsProcessTrusted(), self.startMonitor() else { return }
            t.invalidate()
        }
        rebuildMenu()
    }

    private func startMonitor() -> Bool {
        running = monitor.start()
        NSLog("MHanja: 키 감시 시작 = \(running)")
        rebuildMenu()
        return running
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if !AXIsProcessTrusted() {
            menu.addItem(item("⚠️ 손쉬운 사용 권한 필요…", #selector(openAccessibility)))
            menu.addItem(.separator())
        } else if !running {
            menu.addItem(item("⚠️ 키 감시 시작 실패 — 앱을 다시 실행하세요", #selector(openAccessibility)))
            menu.addItem(.separator())
        }

        let toggle = item("사용", #selector(toggleEnabled))
        toggle.state = monitor.enabled ? .on : .off
        menu.addItem(toggle)

        let triggerMenu = NSMenu()
        for key in TriggerKey.allCases {
            let it = item(key.title, #selector(selectTrigger(_:)))
            it.representedObject = key.rawValue
            it.state = monitor.trigger == key ? .on : .off
            triggerMenu.addItem(it)
        }
        let triggerItem = NSMenuItem(title: "트리거 키", action: nil, keyEquivalent: "")
        triggerItem.submenu = triggerMenu
        menu.addItem(triggerItem)

        let login = item("로그인 시 실행", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("정보…", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    @objc private func toggleEnabled() {
        monitor.enabled.toggle()
        defaults.set(monitor.enabled, forKey: "enabled")
        rebuildMenu()
    }

    @objc private func selectTrigger(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let key = TriggerKey(rawValue: raw) else { return }
        monitor.trigger = key
        defaults.set(raw, forKey: "trigger")
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("로그인 항목 설정 실패: \(error)")
        }
        rebuildMenu()
    }

    @objc private func showAbout() {
        AboutPanel.show()
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
