import AppKit
import Carbon

/// 트리거 키가 macOS나 다른 앱의 단축키와 겹치는지 찾는다.
/// - macOS 키보드 단축키 설정(com.apple.symbolichotkeys)과 늘 쓰이는 기본 단축키
/// - 다른 앱이 독점으로 등록한 전역 단축키 (같은 조합을 독점 등록해 보고 실패하는지로 판단)
/// - 실행 중인 앱의 메뉴 단축키 (손쉬운 사용 API로 메뉴 막대를 읽는다)
/// 일반 방식으로 등록된 전역 단축키나 실행 중이 아닌 앱의 단축키는 알 수 없다.
enum ShortcutConflicts {
    /// 시스템 쪽 충돌 (빠름, 메인 스레드)
    static func system(_ t: Trigger) -> [String] {
        if t.isModifierOnly { return modifierOnly(t) }
        var found: [String] = []

        let hotkeys = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString)
            as? [String: Any] ?? [:]
        var seen = Set<Int>()
        for (key, value) in hotkeys {
            guard let id = Int(key), let entry = value as? [String: Any] else { continue }
            seen.insert(id)
            guard (entry["enabled"] as? Bool) == true,
                  let params = (entry["value"] as? [String: Any])?["parameters"] as? [Int], params.count >= 3,
                  same(t, keyCode: params[1], flags: params[2]) else { continue }
            found.append("macOS: " + (symbolicNames[id] ?? "시스템 단축키"))
        }
        // 설정 파일에 없는 기본 단축키는 켜져 있는 것으로 본다
        for (id, def) in symbolicDefaults where !seen.contains(id) && same(t, keyCode: def.keyCode, flags: Int(def.flags.rawValue)) {
            found.append("macOS: " + (symbolicNames[id] ?? "시스템 단축키"))
        }
        for b in builtIn where same(t, keyCode: b.keyCode, flags: Int(b.flags.rawValue)) {
            found.append("macOS: " + b.name)
        }

        if found.isEmpty && isRegisteredElsewhere(t) {
            found.append("다른 앱 또는 macOS가 전역 단축키로 사용 중")
        }
        if KeyNames.isTopRowFunctionKey(t.keyCode),
           (CFPreferencesCopyAppValue("com.apple.keyboard.fnState" as CFString, kCFPreferencesAnyApplication) as? Bool) != true {
            found.append("F1–F12는 지금 밝기·음량 같은 특수 기능 키로 쓰이고 있어, fn과 함께 눌러야 동작합니다")
        }
        return found
    }

    /// 메뉴와 비교할 그 키의 글자 (입력 소스 API라 메인 스레드에서 구한다)
    static func menuKey(_ t: Trigger) -> (char: String?, shifted: String?) {
        (KeyNames.character(t.keyCode)?.uppercased(), KeyNames.character(t.keyCode, shift: true)?.uppercased())
    }

    /// 실행 중인 앱의 메뉴 단축키 (느릴 수 있어 백그라운드에서 부른다)
    static func menus(_ t: Trigger, key: (char: String?, shifted: String?)) -> [String] {
        guard !t.isModifierOnly else { return [] }
        let (char, shifted) = key
        var found: [String] = []
        var seenAppleMenu = Set<String>()

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != getpid() {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(ax, 0.5)
            guard let bar: AXUIElement = attribute(ax, kAXMenuBarAttribute) else { continue }
            let tops: [AXUIElement] = attribute(bar, kAXChildrenAttribute) ?? []
            for (index, top) in tops.enumerated() {
                let topTitle: String = attribute(top, kAXTitleAttribute) ?? ""
                walk(top, path: index == 0 ? [] : [topTitle], depth: 0) { path, item in
                    guard matches(t, item: item, char: char, shifted: shifted) else { return }
                    let name = path.joined(separator: " > ")
                    if index == 0 { // Apple 메뉴는 모든 앱에 같이 있으니 한 번만
                        if seenAppleMenu.insert(name).inserted { found.append("macOS: Apple 메뉴 > \(name)") }
                    } else {
                        found.append("\(app.localizedName ?? "앱"): \(name)")
                    }
                }
            }
        }
        return found
    }

    // MARK: - 보조키 단독

    private static func modifierOnly(_ t: Trigger) -> [String] {
        guard t.keyCode == 63 else { return [] }
        // 시스템 설정 > 키보드 > "🌐 키를 누르면": 0 동작 안 함, 1 입력 소스 변경, 2 이모티콘, 3 받아쓰기
        let usage = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString) as? Int
        switch usage {
        case 0: return []
        case 1: return ["macOS: 🌐(Fn) 키를 누르면 입력 소스 변경"]
        case 2: return ["macOS: 🌐(Fn) 키를 누르면 이모티콘 및 기호 보기"]
        case 3: return ["macOS: 🌐(Fn) 키를 누르면 받아쓰기 시작"]
        default: return ["macOS: 🌐(Fn) 키에 기능이 지정되어 있을 수 있습니다 (시스템 설정 > 키보드)"]
        }
    }

    // MARK: - 시스템 단축키

    private static func same(_ t: Trigger, keyCode: Int, flags: Int) -> Bool {
        keyCode != 65535 && Int64(keyCode) == t.keyCode
            && CGEventFlags(rawValue: UInt64(flags)).intersection(Trigger.comboFlags) == t.modifiers
    }

    private static func isRegisteredElsewhere(_ t: Trigger) -> Bool {
        var mods: UInt32 = 0
        if t.modifiers.contains(.maskCommand) { mods |= UInt32(cmdKey) }
        if t.modifiers.contains(.maskShift) { mods |= UInt32(shiftKey) }
        if t.modifiers.contains(.maskAlternate) { mods |= UInt32(optionKey) }
        if t.modifiers.contains(.maskControl) { mods |= UInt32(controlKey) }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(t.keyCode), mods, EventHotKeyID(signature: 0x4D48_4A41, id: 1),
                                         GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        if let ref { UnregisterEventHotKey(ref) }
        return status == eventHotKeyExistsErr
    }

    /// 시스템 설정 > 키보드 > 키보드 단축키의 항목 이름 (com.apple.symbolichotkeys의 번호)
    private static let symbolicNames: [Int: String] = [
        7: "메뉴 막대로 초점 이동", 8: "Dock으로 초점 이동", 9: "활성 또는 다음 윈도우로 초점 이동",
        10: "윈도우 도구 막대로 초점 이동", 11: "플로팅 윈도우로 초점 이동", 12: "키보드 접근 켜기/끄기",
        13: "키보드 탐색 켜기/끄기", 15: "확대/축소 켜기/끄기", 17: "확대", 19: "축소", 21: "색상 반전",
        23: "확대/축소 시 이미지 부드럽게 하기", 25: "대비 증가", 26: "대비 감소",
        27: "다음 윈도우로 초점 이동", 28: "스크린샷 (전체 화면)", 29: "스크린샷 (전체 화면)",
        30: "스크린샷 (선택 영역)", 31: "스크린샷 (선택 영역)", 32: "Mission Control",
        33: "응용 프로그램 윈도우", 36: "데스크탑 보기", 52: "Dock 가리기 켜기/끄기", 57: "상태 메뉴로 초점 이동",
        59: "VoiceOver 켜기/끄기", 60: "이전 입력 소스 선택", 61: "입력 메뉴에서 다음 소스 선택",
        64: "Spotlight 검색 보기", 65: "Finder 검색 윈도우 보기", 79: "왼쪽 스페이스로 이동",
        81: "오른쪽 스페이스로 이동", 98: "도움말 메뉴 보기", 160: "Launchpad 보기", 162: "손쉬운 사용 옵션 보기",
        163: "알림 센터 보기", 175: "방해 금지 모드 켜기/끄기", 184: "스크린샷 및 기록 옵션", 190: "빠른 메모",
    ]

    private static let symbolicDefaults: [Int: (keyCode: Int, flags: CGEventFlags)] = [
        27: (50, [.maskCommand]), 28: (20, [.maskCommand, .maskShift]), 29: (20, [.maskControl, .maskCommand, .maskShift]),
        30: (21, [.maskCommand, .maskShift]), 31: (21, [.maskControl, .maskCommand, .maskShift]),
        184: (23, [.maskCommand, .maskShift]), 32: (126, [.maskControl]), 33: (125, [.maskControl]),
        60: (49, [.maskControl]), 61: (49, [.maskControl, .maskAlternate]),
        64: (49, [.maskCommand]), 65: (49, [.maskCommand, .maskAlternate]),
        79: (123, [.maskControl]), 81: (124, [.maskControl]), 98: (44, [.maskCommand, .maskShift]),
        52: (2, [.maskCommand, .maskAlternate]), 59: (96, [.maskCommand]),
    ]

    /// 키보드 단축키 설정에 없지만 늘 동작하는 단축키
    private static let builtIn: [(keyCode: Int, flags: CGEventFlags, name: String)] = [
        (48, [.maskCommand], "앱 전환"), (48, [.maskCommand, .maskShift], "앱 전환 (거꾸로)"),
    ]

    // MARK: - 메뉴

    private static func walk(_ element: AXUIElement, path: [String], depth: Int, visit: ([String], AXUIElement) -> Void) {
        guard depth < 6 else { return }
        for child: AXUIElement in attribute(element, kAXChildrenAttribute) ?? [] {
            let role: String = attribute(child, kAXRoleAttribute) ?? ""
            if role == kAXMenuItemRole {
                let title: String = attribute(child, kAXTitleAttribute) ?? ""
                let childPath = title.isEmpty ? path : path + [title]
                visit(childPath, child)
                walk(child, path: childPath, depth: depth + 1, visit: visit)
            } else {
                walk(child, path: path, depth: depth + 1, visit: visit)
            }
        }
    }

    private static func matches(_ t: Trigger, item: AXUIElement, char: String?, shifted: String?) -> Bool {
        // kAXMenuItemModifier: Shift 1, Option 2, Control 4, Command 없음 8
        guard let raw: Int = attribute(item, "AXMenuItemCmdModifiers") else { return false }
        var mods: CGEventFlags = raw & 8 == 0 ? [.maskCommand] : []
        if raw & 1 != 0 { mods.insert(.maskShift) }
        if raw & 2 != 0 { mods.insert(.maskAlternate) }
        if raw & 4 != 0 { mods.insert(.maskControl) }

        if let key: Int = attribute(item, "AXMenuItemCmdVirtualKey"), (attribute(item, "AXMenuItemCmdChar") as String?)?.isEmpty != false {
            return Int64(key) == t.keyCode && mods == t.modifiers
        }
        guard let cmdChar: String = attribute(item, "AXMenuItemCmdChar"), !cmdChar.isEmpty else { return false }
        let menuChar = cmdChar.uppercased()
        if menuChar == char && mods == t.modifiers { return true }
        // "⌘?"처럼 Shift가 글자에 들어 있는 경우
        return t.modifiers.contains(.maskShift) && menuChar == shifted && menuChar != char
            && mods == t.modifiers.subtracting(.maskShift)
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
