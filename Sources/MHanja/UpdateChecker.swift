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
        let dmg = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag,
                       notes: json["body"] as? String ?? "",
                       pageURL: page,
                       dmgURL: (dmg?["browser_download_url"] as? String).flatMap(URL.init(string:)))
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

    /// 릴리스 설명(마크다운)을 알림 창에 맞게: 표·링크 기호와 강조 표시를 걷어 낸다
    private static func plainText(_ md: String) -> String {
        md.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("|") }
            .map { line in
                var s = line
                for token in ["**", "`", "## ", "# "] { s = s.replacingOccurrences(of: token, with: "") }
                return s
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
