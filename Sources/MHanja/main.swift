import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = KeyMonitor()
    private let updater = UpdateChecker()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private let defaults = UserDefaults.standard
    private var running = false
    private var triggerID = "rightOption"   // 미리 정한 키의 id 또는 "custom"
    private var customTrigger: Trigger?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        triggerID = defaults.string(forKey: "trigger") ?? "rightOption"
        customTrigger = Trigger(dictionary: defaults.dictionary(forKey: "customTrigger"))
        applyTrigger()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.image
        rebuildMenu()
        updater.start()
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
        for preset in Trigger.presets {
            let it = item(preset.trigger.title, #selector(selectTrigger(_:)))
            it.representedObject = preset.id
            it.state = triggerID == preset.id ? .on : .off
            triggerMenu.addItem(it)
        }
        triggerMenu.addItem(.separator())
        let custom = item(customTrigger.map { "사용자 정의: \($0.title)…" } ?? "사용자 정의…", #selector(customizeTrigger))
        custom.state = triggerID == "custom" ? .on : .off
        triggerMenu.addItem(custom)
        let triggerItem = NSMenuItem(title: "트리거 키", action: nil, keyEquivalent: "")
        triggerItem.submenu = triggerMenu
        menu.addItem(triggerItem)

        let login = item("로그인 시 실행", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let autoUpdate = item("자동으로 업데이트 확인", #selector(toggleAutoUpdate))
        autoUpdate.state = updater.automatic ? .on : .off
        menu.addItem(autoUpdate)

        menu.addItem(.separator())
        menu.addItem(item("업데이트 확인…", #selector(checkForUpdates)))
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
        guard let id = sender.representedObject as? String else { return }
        triggerID = id
        defaults.set(id, forKey: "trigger")
        applyTrigger()
        rebuildMenu()
    }

    @objc private func customizeTrigger() {
        monitor.suspended = true
        TriggerRecorder.show(initial: customTrigger, onSave: { [weak self] trigger in
            guard let self else { return }
            self.customTrigger = trigger
            self.triggerID = "custom"
            self.defaults.set(trigger.dictionary, forKey: "customTrigger")
            self.defaults.set("custom", forKey: "trigger")
            self.applyTrigger()
            self.rebuildMenu()
        }, onClose: { [weak self] in
            self?.monitor.suspended = false
        })
    }

    private func applyTrigger() {
        let preset = Trigger.presets.first { $0.id == triggerID }?.trigger
        monitor.trigger = (triggerID == "custom" ? customTrigger : preset) ?? .rightOption
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

    @objc private func toggleAutoUpdate() {
        updater.automatic.toggle()
        rebuildMenu()
    }

    @objc private func checkForUpdates() {
        updater.check(userInitiated: true)
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
