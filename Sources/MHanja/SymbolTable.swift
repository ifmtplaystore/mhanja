import Foundation

/// 윈도우 한글 입력기(KS X 1001)의 "자음 + 한자" 특수문자 표.
enum SymbolTable {
    static let table: [String: [String]] = [
        // ㄱ의 1번은 전각 공백(U+3000, KS X 1001 첫 글자)
        "ㄱ": ["\u{3000}"] + chars("！＇，．／：；？＾＿｀｜￣、。·‥…¨〃―∥＼∼´～ˇ˘˝˚˙¸˛¡¿ː"),
        "ㄴ": chars("＂（）［］｛｝‘’“”〔〕〈〉《》「」『』【】"),
        "ㄷ": chars("＋－＜＝＞±×÷≠≤≥∞∴♂♀∠⊥⌒∂∇≡≒≪≫√∽∝∵∫∬∈∋⊆⊇⊂⊃∪∩∧∨￢⇒⇔∀∃∮∑∏"),
        "ㄹ": chars("＄％￦Ｆ′″℃Å￠￡￥¤℉‰€㎕㎖㎗ℓ㎘㏄㎣㎤㎥㎦㎙㎚㎛㎜㎝㎞㎟㎠㎡㎢㏊㎍㎎㎏㏏㎈㎉㏈㎧㎨㎰㎱㎲㎳㎴㎵㎶㎷㎸㎹㎀㎁㎂㎃㎄㎺㎻㎼㎽㎾㎿㎐㎑㎒㎓㎔Ω㏀㏁㎊㎋㎌㏖㏅㎭㎮㎯㏛㎩㎪㎫㎬㏝㏐㏓㏃㏉㏜㏆"),
        "ㅁ": chars("＃＆＊＠§※☆★○●◎◇◆□■△▲▽▼→←↑↓↔〓◁◀▷▶♤♠♡♥♧♣⊙◈▣◐◑▒▤▥▨▧▦▩♨☏☎☜☞¶†‡↕↗↙↖↘♭♩♪♬㉿㈜№㏇™㏂㏘℡®ªº"),
        "ㅂ": chars("─│┌┐┘└├┬┤┴┼━┃┏┓┛┗┣┳┫┻╋┠┯┨┷┿┝┰┥┸╂┒┑┚┙┖┕┎┍┞┟┡┢┦┧┩┪┭┮┱┲┵┶┹┺┽┾╀╁╃╄╅╆╇╈╉╊"),
        "ㅅ": range(0x3260, 0x327B) + range(0x3200, 0x321B),
        "ㅇ": range(0x24D0, 0x24E9) + range(0x2460, 0x246E) + range(0x249C, 0x24B5) + range(0x2474, 0x2482),
        "ㅈ": range(0xFF10, 0xFF19) + range(0x2170, 0x2179) + range(0x2160, 0x2169),
        "ㅊ": chars("½⅓⅔¼¾⅛⅜⅝⅞¹²³⁴ⁿ₁₂₃₄"),
        "ㅋ": range(0x3131, 0x3163),
        "ㅌ": range(0x3165, 0x318E),
        "ㅍ": range(0xFF21, 0xFF3A) + range(0xFF41, 0xFF5A),
        "ㅎ": range(0x0391, 0x03A1) + range(0x03A3, 0x03A9) + range(0x03B1, 0x03C1) + range(0x03C3, 0x03C9),
        "ㄲ": chars("ÆÐªĦĲĿŁØŒºÞŦŊæđðħıĳĸŀłøœßþŧŋŉ"),
        "ㄸ": range(0x3041, 0x3093),
        "ㅃ": range(0x30A1, 0x30F6),
        "ㅆ": range(0x0410, 0x0415) + ["Ё"] + range(0x0416, 0x0435) + ["ё"] + range(0x0436, 0x044F),
    ]

    static func candidates(for consonant: String) -> [Candidate] {
        (table[consonant] ?? []).map { Candidate(text: $0, note: "") }
    }

    private static func chars(_ s: String) -> [String] { s.map { String($0) } }

    private static func range(_ a: UInt32, _ b: UInt32) -> [String] {
        (a...b).compactMap { Unicode.Scalar($0).map { String($0) } }
    }
}
