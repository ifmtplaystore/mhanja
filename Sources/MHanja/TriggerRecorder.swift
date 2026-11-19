import AppKit
import Carbon

/// 트리거 키 > 사용자 정의…: 사용자가 누른 키(조합)를 받아 충돌을 검사하고 저장한다.
/// 창이 떠 있는 동안에는 ⌘Space 같은 시스템 단축키를 꺼서 그 키도 그대로 받는다.
final class TriggerRecorder: NSObject, NSWindowDelegate {
    private static var current: TriggerRecorder?

    static func show(initial: Trigger?, onSave: @escaping (Trigger) -> Void, onClose: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        if let current { current.window.makeKeyAndOrderFront(nil); return }
        let recorder = TriggerRecorder(initial: initial, onSave: onSave, onClose: onClose)
        current = recorder
        recorder.open()
    }

    private let onSave: (Trigger) -> Void
    private let onClose: () -> Void
    private let window: NSWindow
    private let keyLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let saveButton = NSButton(title: "저장", target: nil, action: nil)
    private var recorded: Trigger?
    private var pendingModifier: Int64?
    private var eventMonitor: Any?
    private var hotKeyMode: UnsafeMutableRawPointer?
    private var checkID = 0

    private let width: CGFloat = 440

    private init(initial: Trigger?, onSave: @escaping (Trigger) -> Void, onClose: @escaping () -> Void) {
        self.onSave = onSave
        self.onClose = onClose
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "트리거 키 사용자 정의"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildContent()
        if let initial { record(initial) } else { showIdle() }
    }

    private func buildContent() {
        let inner = width - 48
        let heading = NSTextField(labelWithString: "트리거로 쓸 키나 키 조합을 누르세요")
        heading.font = .systemFont(ofSize: 14, weight: .semibold)

        let guide = NSTextField(wrappingLabelWithString:
            "• 보조키 하나만 눌렀다 떼기 (예: 왼쪽 Option, 오른쪽 Shift, Fn)\n"
            + "• 키 조합: ⌘·⌥·⌃와 함께 다른 키 (예: ⌃Space, ⌥Return)\n"
            + "• F1–F20은 단독으로도 쓸 수 있습니다")
        guide.font = .systemFont(ofSize: 12)
        guide.textColor = .secondaryLabelColor
        guide.preferredMaxLayoutWidth = inner

        keyLabel.font = .systemFont(ofSize: 24, weight: .medium)
        keyLabel.alignment = .center
        let keyBox = NSBox()
        keyBox.boxType = .custom
        keyBox.cornerRadius = 8
        keyBox.borderColor = .separatorColor
        keyBox.fillColor = .textBackgroundColor
        keyBox.contentViewMargins = NSSize(width: 12, height: 14)
        keyBox.contentView = keyLabel
        keyBox.translatesAutoresizingMaskIntoConstraints = false
        keyBox.widthAnchor.constraint(equalToConstant: inner).isActive = true
        keyBox.heightAnchor.constraint(equalToConstant: 72).isActive = true

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.preferredMaxLayoutWidth = inner
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true

        let note = NSTextField(wrappingLabelWithString:
            "macOS 키보드 단축키, 실행 중인 앱의 메뉴 단축키, 다른 앱이 독점 등록한 전역 단축키를 검사합니다. "
            + "실행 중이 아닌 앱의 단축키는 확인할 수 없습니다.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor
        note.preferredMaxLayoutWidth = inner

        let cancel = NSButton(title: "취소", target: self, action: #selector(cancel))
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.bezelColor = .controlAccentColor
        let buttons = NSStackView(views: [NSView(), cancel, saveButton])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalToConstant: inner).isActive = true
        for b in [cancel, saveButton] { b.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true }

        let stack = NSStackView(views: [heading, guide, keyBox, statusLabel, note, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(18, after: note)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: width),
        ])
        window.contentView = content
    }

    private func open() {
        window.layoutIfNeeded()
        window.center()
        window.makeKeyAndOrderFront(nil)
        hotKeyMode = PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled))
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.handle(event)
            return nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let hotKeyMode { PopSymbolicHotKeyMode(hotKeyMode) }
        hotKeyMode = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        onClose()
        Self.current = nil
    }

    // MARK: - 키 입력

    private func handle(_ event: NSEvent) {
        let keyCode = Int64(event.keyCode)
        let flags = event.cgEvent?.flags ?? []
        let held = flags.intersection(Trigger.comboFlags.union(.maskSecondaryFn))

        switch event.type {
        case .flagsChanged:
            guard let flag = Trigger.modifierKeys[keyCode]?.flag else { return } // Caps Lock 등
            if flags.contains(flag) {
                // 이 보조키 하나만 눌렸을 때만 "단독으로 눌렀다 떼기" 후보
                pendingModifier = held == flag ? keyCode : nil
                showHeld(held)
            } else {
                if pendingModifier == keyCode {
                    record(Trigger(keyCode: keyCode))
                } else if held.isEmpty {
                    if let recorded { record(recorded) } else { showIdle() }
                } else {
                    showHeld(held)
                }
                pendingModifier = nil
            }

        case .keyDown:
            pendingModifier = nil
            guard !event.isARepeat else { return }
            let mods = flags.intersection(Trigger.comboFlags)
            if mods.isEmpty && keyCode == 53 { cancel(); return }                          // Esc
            if mods.isEmpty && (keyCode == 36 || keyCode == 76) && recorded != nil { save(); return } // Return
            if let problem = Trigger.problem(keyCode: keyCode, modifiers: mods) {
                recorded = nil
                checkID += 1
                setKey(Trigger.symbols(mods) + KeyNames.name(keyCode), dim: true)
                setStatus("⛔️ " + problem, color: .systemRed)
                saveButton.isEnabled = false
                return
            }
            record(Trigger(keyCode: keyCode, modifiers: mods))

        default:
            break
        }
    }

    private func showIdle() {
        setKey("키를 누르세요", dim: true)
        setStatus("", color: .labelColor)
        saveButton.isEnabled = false
    }

    private func showHeld(_ held: CGEventFlags) {
        var text = Trigger.symbols(held)
        if held.contains(.maskSecondaryFn) { text = "Fn" + text }
        setKey(text + " …", dim: true)
    }

    private func record(_ trigger: Trigger) {
        recorded = trigger
        setKey(trigger.title, dim: false)
        saveButton.isEnabled = true
        checkID += 1
        let id = checkID

        let system = ShortcutConflicts.system(trigger)
        if trigger.isModifierOnly {
            showResult(system)
            return
        }
        setStatus("충돌하는 단축키를 찾는 중…", color: .secondaryLabelColor)
        let key = ShortcutConflicts.menuKey(trigger)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let menus = ShortcutConflicts.menus(trigger, key: key)
            DispatchQueue.main.async {
                guard let self, self.checkID == id else { return }
                self.showResult(system + menus)
            }
        }
    }

    private func showResult(_ conflicts: [String]) {
        guard !conflicts.isEmpty else {
            setStatus("✅ 충돌하는 단축키를 찾지 못했습니다.", color: .labelColor)
            return
        }
        let shown = conflicts.prefix(5).map { "• " + $0 }
        var text = "⚠️ 이미 쓰이고 있는 키입니다\n" + shown.joined(separator: "\n")
        if conflicts.count > shown.count { text += "\n• 외 \(conflicts.count - shown.count)건" }
        text += "\n저장할 수는 있지만 둘 중 한쪽이 동작하지 않을 수 있습니다. (MHanja는 한글을 입력한 직후에만 이 키를 가로챕니다)"
        setStatus(text, color: .labelColor)
    }

    private func setKey(_ text: String, dim: Bool) {
        keyLabel.stringValue = text
        keyLabel.textColor = dim ? .tertiaryLabelColor : .labelColor
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.stringValue = text
        statusLabel.textColor = color
        fitWindow()
    }

    /// 안내 문구 길이에 맞춰 창 높이를 바꾼다 (위쪽 가장자리는 그대로)
    private func fitWindow() {
        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let height = content.fittingSize.height
        var frame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: width, height: height))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        if window.isVisible { window.setFrame(frame, display: true, animate: false) } else { window.setContentSize(frame.size) }
    }

    @objc private func save() {
        guard let recorded else { return }
        onSave(recorded)
        window.close()
    }

    @objc private func cancel() {
        window.close()
    }
}
