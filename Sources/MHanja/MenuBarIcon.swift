import AppKit

/// 메뉴바용 단색 템플릿 아이콘: 키캡 윤곽 + 채운 윗면(앞쪽이 두꺼움) + 뚫린 ※.
/// isTemplate이라 라이트/다크/강조 상태 색은 시스템이 입힌다.
enum MenuBarIcon {
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(.black)
            ctx.setStrokeColor(.black)

            let outer = CGRect(x: 1.6, y: 1.6, width: 14.8, height: 14.8)
            ctx.addPath(CGPath(roundedRect: outer, cornerWidth: 3.8, cornerHeight: 3.8, transform: nil))
            ctx.setLineWidth(1.2)
            ctx.strokePath()

            let face = CGRect(x: 3.6, y: 5.0, width: 10.8, height: 10.2)
            ctx.addPath(CGPath(roundedRect: face, cornerWidth: 2, cornerHeight: 2, transform: nil))
            ctx.fillPath()

            ctx.setBlendMode(.clear)
            drawReferenceMark(ctx, center: CGPoint(x: face.midX, y: face.midY), size: 8.2)
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "MHanja"
        return img
    }()

    /// ※: 45° 교차선 두 개 + 상하좌우 점 네 개
    private static func drawReferenceMark(_ ctx: CGContext, center c: CGPoint, size: CGFloat) {
        let arm = size * 0.40, dot = size * 0.10, d = size * 0.35
        ctx.setLineWidth(size * 0.15)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x - arm, y: c.y - arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y + arm))
        ctx.move(to: CGPoint(x: c.x - arm, y: c.y + arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y - arm))
        ctx.strokePath()
        for (dx, dy) in [(0, d), (0, -d), (d, 0), (-d, 0)] as [(CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: c.x + dx - dot, y: c.y + dy - dot, width: dot * 2, height: dot * 2))
        }
    }
}
