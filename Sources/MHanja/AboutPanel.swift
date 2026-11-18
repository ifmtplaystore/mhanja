import AppKit

/// 메뉴의 "정보…": 시스템 기본 정보 창에 만든이·문의처·GitHub 페이지와 오픈소스 라이선스 링크를 넣어 띄운다.
/// 앱 이름·버전·아이콘·저작권 줄은 Info.plist에서 가져온다.
enum AboutPanel {
    static let contact = "ifmtplaystore@gmail.com"

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    private static func credits() -> NSAttributedString {
        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
        ]
        let bold = body.merging([.font: NSFont.boldSystemFont(ofSize: 11)]) { $1 }
        let small = body.merging([
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]) { $1 }

        let s = NSMutableAttributedString()
        func add(_ text: String, _ attrs: [NSAttributedString.Key: Any]) {
            s.append(NSAttributedString(string: text, attributes: attrs))
        }

        add("자음·한글 + 트리거 키로 특수문자와 한자를 입력합니다.\n\n", body)
        add("만든이  ", bold)
        add("IFMT\n", body)
        add("문의/건의  ", bold)
        add(contact, body.merging([.link: URL(string: "mailto:\(contact)")!]) { $1 })
        add("\n", body)
        add("GitHub  ", bold)
        add("github.com/\(UpdateChecker.repo)", body.merging([.link: URL(string: "https://github.com/\(UpdateChecker.repo)")!]) { $1 })
        add("\n\n", body)

        // BSD 3-Clause 고지 전문은 앱 번들의 hanja-LICENSE.txt에 두고, 여기서는 링크로만 연다.
        if let url = Bundle.main.url(forResource: "hanja-LICENSE", withExtension: "txt") {
            add("오픈소스 라이선스", small.merging([.link: url]) { $1 })
        }
        return s
    }
}
