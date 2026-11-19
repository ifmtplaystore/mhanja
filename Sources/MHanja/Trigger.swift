import AppKit
import Carbon

/// 트리거 키. 두 가지 꼴이 있다.
/// - 보조키 하나를 단독으로 눌렀다 떼기 (예: 오른쪽 Option) — `modifiers`는 비어 있다
/// - 보조키와 함께 누르는 키 조합, 또는 F키 하나 (예: ⌃Space, F13) — 누르는 순간 실행된다
struct Trigger: Equatable {
    var keyCode: Int64
    var modifiers: CGEventFlags = []

    /// 키 조합에서 비교하는 보조키 (Fn·숫자 패드 표시는 화살표·F키에 저절로 붙으므로 뺀다)
    static let comboFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

    static let modifierKeys: [Int64: (flag: CGEventFlags, name: String)] = [
        61: (.maskAlternate, "오른쪽 Option"), 58: (.maskAlternate, "왼쪽 Option"),
        54: (.maskCommand, "오른쪽 Command"), 55: (.maskCommand, "왼쪽 Command"),
        62: (.maskControl, "오른쪽 Control"), 59: (.maskControl, "왼쪽 Control"),
        60: (.maskShift, "오른쪽 Shift"), 56: (.maskShift, "왼쪽 Shift"),
        63: (.maskSecondaryFn, "Fn"),
    ]

    static let rightOption = Trigger(keyCode: 61)
    static let presets: [(id: String, trigger: Trigger)] = [
        ("rightOption", .rightOption), ("rightCommand", Trigger(keyCode: 54)), ("rightControl", Trigger(keyCode: 62)),
    ]

    var isModifierOnly: Bool { Self.modifierKeys[keyCode] != nil }
    var modifierFlag: CGEventFlags? { Self.modifierKeys[keyCode]?.flag }

    var title: String {
        if let m = Self.modifierKeys[keyCode] { return m.name }
        return Self.symbols(modifiers) + KeyNames.name(keyCode)
    }

    /// 키 조합 트리거가 이 keyDown과 맞는지
    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        !isModifierOnly && keyCode == self.keyCode && flags.intersection(Self.comboFlags) == modifiers
    }

    /// 트리거로 쓸 수 없는 키 조합이면 그 이유
    static func problem(keyCode: Int64, modifiers: CGEventFlags) -> String? {
        if keyCode == 57 { return "Caps Lock은 트리거로 쓸 수 없습니다." }
        if modifiers.intersection([.maskCommand, .maskAlternate, .maskControl]).isEmpty && !KeyNames.isFunctionKey(keyCode) {
            return "글자를 입력하는 키입니다. Command·Option·Control 중 하나와 함께 누르세요. (F1–F20은 단독으로 쓸 수 있습니다)"
        }
        return nil
    }

    /// ⌃⌥⇧⌘ 순서의 보조키 기호
    static func symbols(_ flags: CGEventFlags) -> String {
        [(CGEventFlags.maskControl, "⌃"), (.maskAlternate, "⌥"), (.maskShift, "⇧"), (.maskCommand, "⌘")]
            .filter { flags.contains($0.0) }.map(\.1).joined()
    }

    // UserDefaults 저장
    init(keyCode: Int64, modifiers: CGEventFlags = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.comboFlags)
    }

    init?(dictionary: [String: Any]?) {
        guard let code = dictionary?["keyCode"] as? Int, let mods = dictionary?["modifiers"] as? Int else { return nil }
        self.init(keyCode: Int64(code), modifiers: CGEventFlags(rawValue: UInt64(mods)))
    }

    var dictionary: [String: Any] { ["keyCode": Int(keyCode), "modifiers": Int(modifiers.rawValue)] }
}

/// 키코드 → 표시 이름·글자
enum KeyNames {
    private static let functionKeys: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]
    private static let special: [Int64: String] = [
        49: "Space", 36: "Return", 76: "Enter", 48: "Tab", 51: "Delete", 117: "⌦", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down", 114: "Help",
    ]

    static func isFunctionKey(_ keyCode: Int64) -> Bool { functionKeys[keyCode] != nil }

    /// F1–F12 (기본 설정에서는 밝기·음량 같은 특수 기능 키)
    static func isTopRowFunctionKey(_ keyCode: Int64) -> Bool {
        guard let name = functionKeys[keyCode], let n = Int(name.dropFirst()) else { return false }
        return n <= 12
    }

    static func name(_ keyCode: Int64) -> String {
        functionKeys[keyCode] ?? special[keyCode] ?? character(keyCode)?.uppercased() ?? "키 \(keyCode)"
    }

    /// 영문 자판 기준으로 그 키가 내는 글자 (한글 입력 중이어도 Q, W …)
    static func character(_ keyCode: Int64, shift: Bool = false) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0, length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { buf in
            UCKeyTranslate(buf.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self), UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay), shift ? UInt32(shiftKey >> 8) : 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
