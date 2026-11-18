import Foundation

struct Candidate {
    let text: String
    let note: String
}

/// 한 음절의 한자 후보: basic은 기본 목록, all은 Tab으로 펼친 전체 목록.
struct HanjaCandidates {
    let basic: [Candidate]
    let all: [Candidate]
}

/// 음절 → 한자 후보 (Resources/hanja.tsv: "음\t한자\t뜻")
/// 기본 목록은 훈이 있는 KS X 1001 한자만, 전체 목록은 그 뒤에 나머지 한자(훈 있는 것 먼저)를 붙인다.
enum HanjaDictionary {
    private static let table: [String: HanjaCandidates] = {
        guard let url = Bundle.main.url(forResource: "hanja", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("hanja.tsv를 찾을 수 없음")
            return [:]
        }
        var raw: [String: [Candidate]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let reading = String(parts[0])
            let note = parts.count > 2 ? meaning(String(parts[2]), reading: reading) : ""
            raw[reading, default: []].append(Candidate(text: String(parts[1]), note: note))
        }
        return raw.mapValues { list in
            // 우선순위: KS X 1001+훈 → 그 밖의 한자+훈 → KS X 1001(훈 없음) → 나머지
            let ks = list.filter { isKSX1001($0.text) }, rest = list.filter { !isKSX1001($0.text) }
            let basic = ks.filter { hasMeaning($0.note) }
            let otherWithMeaning = rest.filter { hasMeaning($0.note) }
            let all = basic + otherWithMeaning
                + ks.filter { !hasMeaning($0.note) } + rest.filter { !hasMeaning($0.note) }
            // 기본 목록이 빈 음절은 훈 있는 한자를, 그것도 없으면 전체를 처음부터 보여 준다
            let fallback = otherWithMeaning.isEmpty ? all : otherWithMeaning
            return HanjaCandidates(basic: basic.isEmpty ? fallback : basic, all: all)
        }
    }()

    static func candidates(for syllable: String) -> HanjaCandidates? {
        table[syllable]
    }

    private static let eucKR = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))

    /// KS X 1001(완성형) 한자 4,888자에 드는지: EUC-KR로 인코딩되는지로 판단
    private static func isKSX1001(_ s: String) -> Bool {
        s.data(using: eucKR) != nil
    }

    /// 뜻(훈)이 있는지. "禮의 古字", "是와 同字" 같은 이체자 설명(한자가 들어 있음)은 훈으로 치지 않는다.
    private static func hasMeaning(_ note: String) -> Bool {
        !note.isEmpty && !note.unicodeScalars.contains { $0.properties.isIdeographic }
    }

    /// "한탄할 한, 한될 한" → "한탄할": 음으로 끝나는 첫 뜻에서 음을 뗀 훈만 남긴다.
    /// 그런 뜻이 없으면("歌와 同字" 등) 첫 항목을 그대로 쓴다.
    private static func meaning(_ note: String, reading: String) -> String {
        let items = note.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for item in items {
            guard let space = item.lastIndex(of: " ") else { continue }
            let hun = item[..<space].trimmingCharacters(in: .whitespaces)
            if !hun.isEmpty, sameRhyme(String(item[item.index(after: space)...]), reading) { return hun }
        }
        return items.first ?? ""
    }

    /// 중성·종성이 같은 음절인지 (두음법칙: 량/양, 녀/여, 라/나를 같은 음으로 본다)
    private static func sameRhyme(_ a: String, _ b: String) -> Bool {
        guard a.unicodeScalars.count == 1, b.unicodeScalars.count == 1,
              let x = a.unicodeScalars.first?.value, let y = b.unicodeScalars.first?.value,
              (0xAC00...0xD7A3).contains(x), (0xAC00...0xD7A3).contains(y) else { return false }
        return (x - 0xAC00) % 588 == (y - 0xAC00) % 588
    }
}
