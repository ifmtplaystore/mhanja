import AppKit
import ApplicationServices

/// Chromium 브라우저·Electron 앱은 보조 기술이 요청해야 웹 콘텐츠의 접근성 정보(커서 위치 등)를 만든다.
/// 앱이 앞으로 올 때 미리 켜 두어, 트리거 키를 눌렀을 때 바로 커서 위치를 얻을 수 있게 한다.
enum AccessibilityBooster {
    /// AXEnhancedUserInterface가 필요한 Chromium 계열 브라우저
    private static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "org.chromium.Chromium", "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "company.thebrowser.Browser", "com.naver.Whale",
    ]
    private static var boosted = Set<pid_t>()
    private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            boost(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
        boost(NSWorkspace.shared.frontmostApplication)
    }

    static func boost(_ app: NSRunningApplication?) {
        guard let app, !boosted.contains(app.processIdentifier) else { return }
        boosted.insert(app.processIdentifier)
        let el = AXUIElementCreateApplication(app.processIdentifier)
        // Electron 앱용 (다른 앱은 무시한다)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if let id = app.bundleIdentifier, chromiumBrowsers.contains(id) {
            AXUIElementSetAttributeValue(el, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }
}
