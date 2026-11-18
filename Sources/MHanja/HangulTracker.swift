import Foundation

/// 두벌식 키 입력을 따라가며 현재 조합 중인 글자를 추적한다.
/// - 단독 자음(예: "한" 뒤의 ㅁ) → `pendingConsonant`
/// - 조합 중인 음절(예: "한") → `pendingSyllable`
final class HangulTracker {
    // 현재 음절을 이루는 키 입력들
    private var cho: String?
    private var jung: [String] = []
    private var jong: [String] = []

    var pendingConsonant: String? {
        jung.isEmpty ? cho : nil
    }

    /// 조합 중인 음절과, 그것을 지우는 데 필요한 백스페이스 횟수
    var pendingSyllable: (text: String, keystrokes: Int)? {
        guard let cho, let c = Self.choList.firstIndex(of: cho),
              let v = Self.jungList.firstIndex(of: Self.combinedVowel(jung)),
              let j = Self.jongList.firstIndex(of: Self.combinedFinal(jong)),
              let scalar = Unicode.Scalar(0xAC00 + (c * 21 + v) * 28 + j) else { return nil }
        return (String(scalar), 1 + jung.count + jong.count)
    }

    // 키코드 → (기본, Shift)
    private static let keymap: [Int64: (String, String)] = [
        12: ("ㅂ", "ㅃ"), 13: ("ㅈ", "ㅉ"), 14: ("ㄷ", "ㄸ"), 15: ("ㄱ", "ㄲ"), 17: ("ㅅ", "ㅆ"),
        16: ("ㅛ", "ㅛ"), 32: ("ㅕ", "ㅕ"), 34: ("ㅑ", "ㅑ"), 31: ("ㅐ", "ㅒ"), 35: ("ㅔ", "ㅖ"),
        0: ("ㅁ", "ㅁ"), 1: ("ㄴ", "ㄴ"), 2: ("ㅇ", "ㅇ"), 3: ("ㄹ", "ㄹ"), 5: ("ㅎ", "ㅎ"),
        4: ("ㅗ", "ㅗ"), 38: ("ㅓ", "ㅓ"), 40: ("ㅏ", "ㅏ"), 37: ("ㅣ", "ㅣ"),
        6: ("ㅋ", "ㅋ"), 7: ("ㅌ", "ㅌ"), 8: ("ㅊ", "ㅊ"), 9: ("ㅍ", "ㅍ"),
        11: ("ㅠ", "ㅠ"), 45: ("ㅜ", "ㅜ"), 46: ("ㅡ", "ㅡ"),
    ]

    private static let choList = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
    private static let jungList = ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
    private static let jongList = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]

    private static let compoundVowel: [String: String] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ",
    ]
    private static let compoundFinal: [String: String] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ",
        "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]

    private static func combinedVowel(_ v: [String]) -> String {
        v.count == 2 ? compoundVowel[v.joined()] ?? "" : v.first ?? ""
    }

    private static func combinedFinal(_ f: [String]) -> String {
        f.count == 2 ? compoundFinal[f.joined()] ?? "" : f.first ?? ""
    }

    func reset() {
        cho = nil
        jung = []
        jong = []
    }

    func handle(keyCode: Int64, shift: Bool) {
        guard let pair = Self.keymap[keyCode] else { reset(); return }
        let jamo = shift ? pair.1 : pair.0
        if Self.jungList.contains(jamo) { addVowel(jamo) } else { addConsonant(jamo) }
    }

    /// 백스페이스: 조합 중인 글자에서 자모 하나를 지운다.
    func backspace() {
        if !jong.isEmpty { jong.removeLast() }
        else if !jung.isEmpty { jung.removeLast() }
        else { reset() }
        if cho == nil && jung.isEmpty { reset() }
    }

    private func addConsonant(_ c: String) {
        if cho != nil && !jung.isEmpty {
            switch jong.count {
            case 0 where Self.jongList.contains(c):
                jong = [c]
                return
            case 1 where Self.compoundFinal[jong[0] + c] != nil:
                jong.append(c)
                return
            default:
                break
            }
        }
        startSyllable(cho: c, jung: [])
    }

    private func addVowel(_ v: String) {
        if cho != nil && jung.isEmpty {
            jung = [v]
        } else if jung.count == 1 && jong.isEmpty && Self.compoundVowel[jung[0] + v] != nil {
            jung.append(v)
        } else if let moved = jong.last {
            // 받침이 다음 음절의 초성으로 넘어감 (한 + ㅏ → 하나)
            jong.removeLast()
            startSyllable(cho: moved, jung: [v])
        } else {
            startSyllable(cho: nil, jung: [v])
        }
    }

    private func startSyllable(cho: String?, jung: [String]) {
        self.cho = cho
        self.jung = jung
        self.jong = []
    }
}
