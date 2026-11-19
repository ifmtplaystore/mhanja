import AppKit
import Carbon

/// 전역 키 입력을 감시해 "자음/음절 + 트리거 키"를 감지한다.
final class KeyMonitor {
    var enabled = true
    var trigger: Trigger = .rightOption
    /// 트리거 키 사용자 정의 창이 열려 있는 동안에는 아무것도 가로채지 않는다
    var suspended = false

    private let tracker = HangulTracker()
    private let panel = CandidatePanel()
    private var tap: CFMachPort?
    private var triggerDown = false
    private var otherKeyWhileTrigger = false
    private var keystrokesToReplace = 0
    private var swallowedKey: Int64?   // 키 조합 트리거로 삼킨 키 (짝이 되는 keyUp·자동 반복도 삼킨다)

    init() {
        panel.onSelect = { [weak self] text in
            guard let self else { return }
            self.tracker.reset()
            TextInserter.replaceComposition(keystrokes: self.keystrokesToReplace, with: text)
        }
    }

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, info in
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(info!).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AccessibilityBooster.start()
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if suspended || event.getIntegerValueField(.eventSourceUserData) == TextInserter.marker { return pass }

        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == swallowedKey {
                swallowedKey = nil
                return nil
            }
        case .flagsChanged:
            handleFlagsChanged(event)
        case .leftMouseDown, .rightMouseDown:
            tracker.reset()
            if panel.isVisible && !panel.frame.contains(NSEvent.mouseLocation) { panel.hide() }
        default:
            break
        }
        return pass
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if triggerDown { otherKeyWhileTrigger = true }

        // 키 조합 트리거: 바꿀 글자가 있을 때만 가로채고, 아니면 원래 단축키로 그대로 보낸다
        if trigger.matches(keyCode: keyCode, flags: flags) {
            if swallowedKey == keyCode && event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
            if panel.isVisible {
                panel.hide()
                swallowedKey = keyCode
                return nil
            }
            if fire() {
                swallowedKey = keyCode
                return nil
            }
        }

        if panel.isVisible {
            if panel.handleKey(keyCode: keyCode, shift: flags.contains(.maskShift)) { return nil }
            panel.hide() // 다른 키: 창을 닫고 원래대로 입력되게 둔다
        }

        guard enabled, Self.isKorean2Set() else { tracker.reset(); return Unmanaged.passUnretained(event) }
        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            tracker.reset()
        } else if keyCode == 51 {
            tracker.backspace()
        } else {
            tracker.handle(keyCode: keyCode, shift: flags.contains(.maskShift))
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let flag = trigger.modifierFlag, keyCode == trigger.keyCode else {
            if triggerDown { otherKeyWhileTrigger = true }
            return
        }
        if event.flags.contains(flag) {
            triggerDown = true
            otherKeyWhileTrigger = false
        } else {
            if triggerDown && !otherKeyWhileTrigger { fire() }
            triggerDown = false
        }
    }

    /// 후보 창을 띄웠으면 true
    @discardableResult
    private func fire() -> Bool {
        guard enabled, !panel.isVisible else { return false }
        let items: [Candidate]
        let expanded: [Candidate]?
        let title: String
        if let consonant = tracker.pendingConsonant {
            items = SymbolTable.candidates(for: consonant)
            expanded = items
            title = "\(consonant) 특수문자"
            keystrokesToReplace = 1
        } else if let syllable = tracker.pendingSyllable, let hanja = HanjaDictionary.candidates(for: syllable.text) {
            items = hanja.basic
            expanded = hanja.all.count > hanja.basic.count ? hanja.all : nil
            title = "\(syllable.text) 한자"
            keystrokesToReplace = syllable.keystrokes
        } else {
            return false
        }
        guard !items.isEmpty else { return false }
        panel.show(items: items, expanded: expanded, title: title, caret: TextInserter.caretRect())
        return true
    }

    /// 현재 입력 소스가 두벌식 한글인지
    private static func isKorean2Set() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let id = (Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String).lowercased()
        return id.contains("2set") || id.contains("han2")
    }
}
