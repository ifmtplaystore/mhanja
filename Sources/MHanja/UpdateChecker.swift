import AppKit

/// GitHub Releases의 최신 버전을 확인해 새 버전이 있으면 알려 준다. 설치는 사용자가 DMG로 직접 한다.
final class UpdateChecker {
    static let repo = "ifmtplaystore/mhanja"

    private let defaults = UserDefaults.standard
    private let interval: TimeInterval = 24 * 60 * 60
    private var timer: Timer?
    private var checking = false

    /// 메뉴의 "자동으로 업데이트 확인"
    var automatic: Bool {
        get { defaults.object(forKey: "autoUpdateCheck") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoUpdateCheck") }
    }

    private struct Release {
        let version: String
        let notes: String
        let pageURL: URL
        let dmgURL: URL?
    }

    /// 실행 직후와 이후 하루마다, 마지막 확인에서 하루가 지났으면 조용히 확인한다.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in self?.checkIfDue() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkIfDue() }
    }

    private func checkIfDue() {
        guard automatic else { return }
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= interval { check(userInitiated: false) }
    }

    /// userInitiated면 최신 버전이거나 확인에 실패해도 결과를 알려 주고, 건너뛴 버전도 다시 보여 준다.
    func check(userInitiated: Bool) {
        guard !checking else { return }
        checking = true
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            let release = data.flatMap(Self.parse)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200 && release != nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                if ok { self.defaults.set(Date(), forKey: "lastUpdateCheck") }
                self.handle(ok ? release : nil, userInitiated: userInitiated)
            }
        }.resume()
    }

    private func handle(_ release: Release?, userInitiated: Bool) {
        guard let release else {
            if userInitiated { alert("업데이트를 확인하지 못했습니다", "인터넷 연결을 확인한 뒤 다시 시도해 주세요.") }
            return
        }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard Self.isNewer(release.version, than: current) else {
            if userInitiated { alert("최신 버전을 사용하고 있습니다", "MHanja \(current)") }
            return
        }
        if !userInitiated, defaults.string(forKey: "skippedVersion") == release.version { return }
        offer(release, current: current, userInitiated: userInitiated)
    }

    private func offer(_ release: Release, current: String, userInitiated: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "MHanja \(release.version) 업데이트가 있습니다"
        var info = "지금 버전은 \(current)입니다. 다운로드한 DMG를 열어 응용 프로그램 폴더의 MHanja를 바꾸면 됩니다."
        let notes = Self.plainText(release.notes)
        if !notes.isEmpty { info += "\n\n" + (notes.count > 600 ? notes.prefix(600) + "…" : notes) }
        a.informativeText = info
        a.addButton(withTitle: "다운로드")
        a.addButton(withTitle: "나중에")
        if !userInitiated { a.addButton(withTitle: "이 버전 건너뛰기") }
        switch a.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.dmgURL ?? release.pageURL)
        case .alertThirdButtonReturn:
            defaults.set(release.version, forKey: "skippedVersion")
        default:
            break
        }
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }

    private static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let assets = json["assets"] as? [[String: Any]] ?? []
        let dmg = assets.first { ($0["name"] as? String).map(isDMGForThisMac) == true }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag,
                       notes: json["body"] as? String ?? "",
                       pageURL: page,
                       dmgURL: (dmg?["browser_download_url"] as? String).flatMap(URL.init(string:)))
    }

    /// CPU별 DMG 중 이 앱과 같은 것: Intel은 "MHanja-Intel.dmg", Apple Silicon은 "MHanja.dmg"
    private static func isDMGForThisMac(_ name: String) -> Bool {
        guard name.hasSuffix(".dmg") else { return false }
        #if arch(x86_64)
        return name.contains("Intel")
        #else
        return !name.contains("Intel")
        #endif
    }

    /// "1.10" > "1.9" 처럼 점으로 나눈 숫자를 차례로 비교
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    /// 릴리스 설명(마크다운)에서 첫 섹션(예: "바뀐 점")만 평문으로: 제목·강조·코드 표시를 떼고 링크는 글자만 남긴다.
    /// 업데이트 방법·파일 표 같은 나머지 섹션은 알림 창 안내와 겹치므로 보여 주지 않는다.
    static func plainText(_ md: String) -> String {
        var lines: [String] = []
        var seenHeading = false
        for line in md.components(separatedBy: .newlines) {
            if line.hasPrefix("#") {
                if seenHeading || lines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { break }
                seenHeading = true
                continue
            }
            if line.hasPrefix("|") { continue }
            var s = line.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            for token in ["**", "`"] { s = s.replacingOccurrences(of: token, with: "") }
            lines.append(s)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
