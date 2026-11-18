// 앱 아이콘(E1-K 상아 키캡) 원본 생성: swiftc -O AppIcon.swift -o /tmp/appicon && /tmp/appicon <출력폴더>

import AppKit
import CoreImage
import CoreText

// macOS 아이콘 그리드: 1024 캔버스, 824x824 본체(여백 100), 연속 곡률 모서리
let S: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)

func squircle(_ r: CGRect, n: CGFloat = 5) -> CGPath {
    let p = CGMutablePath()
    let cx = r.midX, cy = r.midY, a = r.width / 2, b = r.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c >= 0 ? 1 : -1) * pow(abs(c), 2 / n)
        let y = cy + b * (s >= 0 ? 1 : -1) * pow(abs(s), 2 / n)
        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
    }
    p.closeSubpath()
    return p
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func font(_ names: [String], _ size: CGFloat) -> CTFont {
    for n in names {
        let f = CTFontCreateWithName(n as CFString, size, nil)
        if (CTFontCopyPostScriptName(f) as String) == n { return f }
    }
    fatalError("font not found: \(names)")
}

/// 문자열 외곽선 경로를 만들어 (cx, cy)에 시각적 중앙 정렬
func textPath(_ s: String, _ f: CTFont, center: CGPoint) -> CGPath {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &pos)
        let rf = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        for i in 0..<n {
            if let g = CTFontCreatePathForGlyph(rf, glyphs[i], nil) {
                path.addPath(g, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y))
            }
        }
    }
    let bb = path.boundingBoxOfPath
    var t = CGAffineTransform(translationX: center.x - bb.midX, y: center.y - bb.midY)
    return path.copy(using: &t)!
}

func linear(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func fill(_ ctx: CGContext, _ p: CGPath, _ c: CGColor) { ctx.addPath(p); ctx.setFillColor(c); ctx.fillPath() }

func clipped(_ ctx: CGContext, _ p: CGPath, _ draw: () -> Void) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip(); draw(); ctx.restoreGState()
}

func withShadow(_ ctx: CGContext, dy: CGFloat, blur: CGFloat, _ c: CGColor, _ draw: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -dy), blur: blur, color: c); draw(); ctx.restoreGState()
}
func render(_ name: String, _ draw: (CGContext) -> Void) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/\(name).png"))
}
/// 굵은 ※: 45° 교차선 두 개 + 상하좌우 점 네 개
func referenceMark(_ ctx: CGContext, center c: CGPoint, size: CGFloat, color: CGColor) {
    let arm = size * 0.40, w = size * 0.13, dot = size * 0.088, d = size * 0.34
    ctx.saveGState()
    ctx.setStrokeColor(color); ctx.setLineWidth(w); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: c.x - arm, y: c.y - arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y + arm))
    ctx.move(to: CGPoint(x: c.x - arm, y: c.y + arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y - arm))
    ctx.strokePath()
    ctx.setFillColor(color)
    for (dx, dy) in [(0, d), (0, -d), (d, 0), (-d, 0)] as [(CGFloat, CGFloat)] {
        ctx.fillEllipse(in: CGRect(x: c.x + dx - dot, y: c.y + dy - dot, width: dot * 2, height: dot * 2))
    }
    ctx.restoreGState()
}


/// 별도 레이어에 그린 뒤 가우시안 블러를 걸어 합성 (면 사이 경계를 부드럽게)
func blurredLayer(_ ctx: CGContext, radius: CGFloat, _ draw: (CGContext) -> Void) {
    let l = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(l)
    let ci = CIImage(cgImage: l.makeImage()!).clampedToExtent().applyingGaussianBlur(sigma: Double(radius))
    let out = CIContext().createCGImage(ci, from: CGRect(x: 0, y: 0, width: S, height: S))!
    ctx.draw(out, in: CGRect(x: 0, y: 0, width: S, height: S))
}

func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }

/// 위에서 내려다본 키캡: 네 경사면(위 얇고 아래 두꺼움) + 오목한 윗면 + 세로 광택띠
func iconKeycapE1(_ ctx: CGContext) {
    let outer = squircle(body)
    let face = CGRect(x: 198, y: 270, width: 628, height: 592)   // 위 62 / 좌우 98 / 아래 170
    let fp = CGPath(roundedRect: face, cornerWidth: 54, cornerHeight: 54, transform: nil)

    // 바닥 그림자
    withShadow(ctx, dy: 18, blur: 34, rgb(0x3A2E18, 0.32)) { fill(ctx, outer, rgb(0xC9BB9C)) }

    clipped(ctx, outer) {
        // 경사면 4개: 바깥 모서리 ↔ 윗면 모서리를 잇는 사다리꼴, 경계는 블러로 부드럽게
        let o = body.insetBy(dx: -40, dy: -40), f = face.insetBy(dx: 16, dy: 16)
        let tl = CGPoint(x: o.minX, y: o.maxY), tr = CGPoint(x: o.maxX, y: o.maxY)
        let bl = CGPoint(x: o.minX, y: o.minY), br = CGPoint(x: o.maxX, y: o.minY)
        let ftl = CGPoint(x: f.minX, y: f.maxY), ftr = CGPoint(x: f.maxX, y: f.maxY)
        let fbl = CGPoint(x: f.minX, y: f.minY), fbr = CGPoint(x: f.maxX, y: f.minY)
        blurredLayer(ctx, radius: 5) { l in
            fill(l, poly([tl, tr, ftr, ftl]), rgb(0xF7F1E4))   // 위: 빛을 정면으로 받음
            fill(l, poly([tl, ftl, fbl, bl]), rgb(0xECE2CB))   // 왼쪽
            fill(l, poly([tr, br, fbr, ftr]), rgb(0xD5C7A7))   // 오른쪽
            fill(l, poly([bl, fbl, fbr, br]), rgb(0xCBBB97))   // 아래: 가장 넓고 어두움
        }
        // 아래 경사면: 윗면 쪽은 밝게, 바깥 아래쪽으로 갈수록 어둡게
        linear(ctx, [rgb(0xFFFFFF, 0), rgb(0x5A4320, 0.10)],
               from: CGPoint(x: 0, y: face.minY), to: CGPoint(x: 0, y: body.minY))
        // 오른쪽 아래 모서리 음영
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [rgb(0x5A4320, 0.10), rgb(0x5A4320, 0)] as CFArray, locations: nil)!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: body.maxX, y: body.minY), startRadius: 0,
                               endCenter: CGPoint(x: body.maxX, y: body.minY), endRadius: 300, options: [])
        // 바깥 테두리: 위·왼쪽 가장자리를 밝게 (모서리가 둥글게 깎인 느낌)
        ctx.saveGState()
        ctx.addPath(outer); ctx.setStrokeColor(rgb(0xFFFFFF, 0.75)); ctx.setLineWidth(10)
        ctx.strokePath()
        ctx.restoreGState()
    }
    // 아래 바깥 가장자리 어두운 선
    clipped(ctx, outer) {
        var t = CGAffineTransform(translationX: 0, y: 6)
        let shifted = outer.copy(using: &t)!
        ctx.addPath(outer); ctx.addPath(shifted); ctx.setFillColor(rgb(0x7A6A48, 0.35)); ctx.fillPath(using: .evenOdd)
    }

    // 윗면: 아래 경사면 위에 살짝 그림자
    withShadow(ctx, dy: 10, blur: 18, rgb(0x5A4320, 0.20)) { fill(ctx, fp, rgb(0xF3ECDD)) }
    clipped(ctx, fp) {
        linear(ctx, [rgb(0xF4EEE1), rgb(0xFAF6EC)], from: CGPoint(x: 0, y: face.maxY), to: CGPoint(x: 0, y: face.minY))
        // 오목한 접시: 위쪽 가장자리에 옅은 그늘
        linear(ctx, [rgb(0x6A5430, 0.08), rgb(0x6A5430, 0)],
               from: CGPoint(x: 0, y: face.maxY), to: CGPoint(x: 0, y: face.maxY - 120))
        // 오른쪽 세로 광택띠
        let band = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0xFFFFFF, 0), rgb(0xFFFFFF, 0.75), rgb(0xFFFFFF, 0.55), rgb(0xFFFFFF, 0)] as CFArray,
                              locations: [0, 0.35, 0.7, 1])!
        ctx.drawLinearGradient(band, start: CGPoint(x: face.minX + face.width * 0.70, y: 0),
                               end: CGPoint(x: face.minX + face.width * 0.93, y: 0), options: [])
        // 윗면 테두리 안쪽: 위는 밝은 립, 아래는 그늘
        var up = CGAffineTransform(translationX: 0, y: -5)
        ctx.addPath(fp.copy(using: &up)!); ctx.setStrokeColor(rgb(0xFFFFFF, 0.9)); ctx.setLineWidth(8); ctx.strokePath()
        var dn = CGAffineTransform(translationX: 0, y: 5)
        ctx.addPath(fp.copy(using: &dn)!); ctx.setStrokeColor(rgb(0x6A5430, 0.12)); ctx.setLineWidth(8); ctx.strokePath()
    }
    ctx.addPath(fp); ctx.setStrokeColor(rgb(0x8A7650, 0.18)); ctx.setLineWidth(2); ctx.strokePath()

    // 각인 ※ (윗면에 인쇄된 느낌으로 아주 얕은 그림자)
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 3, color: rgb(0x6A1A0E, 0.22))
    referenceMark(ctx, center: CGPoint(x: face.midX, y: face.midY), size: 400, color: rgb(0xD23B26)); ctx.restoreGState()

    ctx.addPath(outer); ctx.setStrokeColor(rgb(0x000000, 0.10)); ctx.setLineWidth(2); ctx.strokePath()
}

render("E1k-ivory-keycap") { iconKeycapE1($0) }
print("ok")
