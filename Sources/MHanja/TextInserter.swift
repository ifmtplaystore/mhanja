import AppKit
import ApplicationServices

/// 조합 중인 글자를 지우고 기호/한자를 붙여넣는다.
enum TextInserter {
    /// 우리가 만든 이벤트를 이벤트 탭에서 무시하기 위한 표식
    static let marker: Int64 = 0x4D48_414E

    /// 조합 중 백스페이스는 자모 단위로 지워지므로 키 입력 수만큼 누른다.
    static func replaceComposition(keystrokes: Int, with symbol: String) {
        for _ in 0..<keystrokes { postKey(51) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            paste(symbol)
        }
    }

    private static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let saved = pb.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []

        pb.clearContents()
        pb.setString(text, forType: .string)
        let ourChange = pb.changeCount

        postKey(9, flags: .maskCommand) // Cmd+V

        // 붙여넣기가 끝난 뒤 원래 클립보드 복원 (그 사이 사용자가 복사했다면 건드리지 않음)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard pb.changeCount == ourChange else { return }
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: marker)
            e.post(tap: .cgSessionEventTap)
        }
    }

    /// 포커스된 텍스트의 커서 위치 (Cocoa 좌표). 커서를 못 찾으면 입력란 위치, 그것도 없으면 nil.
    static func caretRect() -> NSRect? {
        guard let el = focusedElement() else { return nil }
        let field = elementBounds(el)
        // 크롬 주소창처럼 엉뚱한 좌표를 주는 경우가 있어, 입력란 안에 있는 커서 위치만 믿는다
        func plausible(_ r: CGRect) -> Bool {
            guard let field else { return true }
            return field.insetBy(dx: -24, dy: -24).contains(CGPoint(x: r.midX, y: r.midY))
        }
        if let rect = caretBounds(el), plausible(rect) { return cocoaRect(rect) }
        if let rect = textMarkerCaretBounds(el), plausible(rect) { return cocoaRect(rect) }
        return elementFrame(el).map(cocoaRect)
    }

    /// 앞 앱의 포커스된 요소. 못 얻으면 접근성 정보를 켜 달라고 요청한 뒤 다시 묻는다.
    private static func focusedElement() -> AXUIElement? {
        if let el = copyElement(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) { return el }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        if let el = copyElement(app, kAXFocusedUIElementAttribute) { return el }
        AccessibilityBooster.boost(NSWorkspace.shared.frontmostApplication)
        return copyElement(app, kAXFocusedUIElementAttribute)
    }

    /// 커서 위치: 바로 앞 글자(조합 중인 글자) → 커서 자리(길이 0) → 커서 뒤 글자 순으로 시도
    private static func caretBounds(_ el: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        AXValueGetValue(rangeValue as! AXValue, .cfRange, &range)

        var probes = [CFRange(location: range.location, length: 0), CFRange(location: range.location, length: 1)]
        if range.location > 0 { probes.insert(CFRange(location: range.location - 1, length: 1), at: 0) }
        for var probe in probes {
            guard let probeValue = AXValueCreate(.cfRange, &probe) else { continue }
            var boundsRef: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                             probeValue, &boundsRef) == .success,
                  let boundsValue = boundsRef, CFGetTypeID(boundsValue) == AXValueGetTypeID() else { continue }
            var rect = CGRect.zero
            AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect)
            // 일부 앱은 크기 0이나 (0,0)을 돌려준다: 위치가 있으면 쓰고, 아예 없으면 다음 방법
            if rect.origin != .zero || rect.height > 0 {
                return CGRect(x: rect.minX, y: rect.minY, width: max(rect.width, 1), height: max(rect.height, 16))
            }
        }
        return nil
    }

    /// 웹 콘텐츠(Chromium·Safari의 contenteditable 등)는 문자 인덱스 대신 텍스트 마커로 커서 위치를 준다.
    private static func textMarkerCaretBounds(_ el: AXUIElement) -> CGRect? {
        var markerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, "AXSelectedTextMarkerRange" as CFString, &markerRange) == .success,
              let range = markerRange else { return nil }
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, "AXBoundsForTextMarkerRange" as CFString,
                                                         range, &boundsRef) == .success,
              let boundsValue = boundsRef, CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect)
        guard rect.origin != .zero || rect.height > 0 else { return nil }
        return CGRect(x: rect.minX, y: rect.minY, width: max(rect.width, 1), height: max(rect.height, 16))
    }

    /// 커서를 알 수 없을 때: 입력란 왼쪽 위에 한 줄 높이의 자리
    private static func elementFrame(_ el: AXUIElement) -> CGRect? {
        guard let frame = elementBounds(el) else { return nil }
        return CGRect(x: frame.minX + 4, y: frame.minY, width: 1, height: min(frame.height, 22))
    }

    /// 입력란 전체 영역 (AX 좌표)
    private static func elementBounds(_ el: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posValue = posRef, let sizeValue = sizeRef else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: pos, size: size)
    }

    private static func copyElement(_ el: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    /// AX는 주 화면 좌상단 원점 → Cocoa 좌하단 원점으로 변환
    private static func cocoaRect(_ rect: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
