// DMG 창 배경 생성: swiftc -O DMGBackground.swift -o /tmp/dmgbg && /tmp/dmgbg <출력폴더>
// → dmg-background.png(660×460), dmg-background@2x.png. build.sh가 둘을 합쳐 TIFF로 쓴다.
// 아이콘 자리(가운데 기준, 위에서부터): 앱 (180, 200), 응용 프로그램 (480, 200) — design/dmg-settings.py와 맞출 것.
// 아래 받침 띠의 맨 아래는 단색이라, Finder 창 테두리(도구 막대 유무)에 따라 조금 가려져도 티 나지 않는다.

import AppKit

let W: CGFloat = 660, H: CGFloat = 460

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

/// 굵은 ※ (앱 아이콘과 같은 비율)
func referenceMark(_ ctx: CGContext, center c: CGPoint, size: CGFloat, color: CGColor) {
    let arm = size * 0.40, w = size * 0.13, dot = size * 0.088, d = size * 0.34
    ctx.saveGState()
    ctx.setStrokeColor(color); ctx.setFillColor(color)
    ctx.setLineWidth(w); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: c.x - arm, y: c.y - arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y + arm))
    ctx.move(to: CGPoint(x: c.x - arm, y: c.y + arm)); ctx.addLine(to: CGPoint(x: c.x + arm, y: c.y - arm))
    ctx.strokePath()
    for (dx, dy) in [(0, d), (0, -d), (d, 0), (-d, 0)] as [(CGFloat, CGFloat)] {
        ctx.fillEllipse(in: CGRect(x: c.x + dx - dot, y: c.y + dy - dot, width: dot * 2, height: dot * 2))
    }
    ctx.restoreGState()
}

/// 위에서부터 잰 y를 CG 좌표로
func y(_ top: CGFloat) -> CGFloat { H - top }

func text(_ ctx: CGContext, _ s: String, font: String, size: CGFloat, color: CGColor, centerX: CGFloat, top: CGFloat,
          kern: CGFloat = 0) {
    let f = NSFont(name: font, size: size) ?? NSFont.systemFont(ofSize: size)
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: NSColor(cgColor: color)!, .kern: kern])
    let line = CTLineCreateWithAttributedString(attr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centerX - CGFloat(width) / 2, y: y(top) - f.ascender)
    CTLineDraw(line, ctx)
}

func draw(_ ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // 상아색 바탕 (앱 아이콘 윗면 색)
    let bg = CGGradient(colorsSpace: space, colors: [rgb(0xFCF9F2), rgb(0xF2EADA)] as CFArray, locations: nil)!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

    // 아래쪽 키보드 받침 띠: 키캡 앞면처럼 살짝 어두운 면 + 윗선 하이라이트
    let deck = CGRect(x: 0, y: 0, width: W, height: 124)
    let deckGrad = CGGradient(colorsSpace: space, colors: [rgb(0xE9DEC7), rgb(0xDDD0B4)] as CFArray, locations: nil)!
    ctx.saveGState(); ctx.clip(to: deck)
    ctx.drawLinearGradient(deckGrad, start: CGPoint(x: 0, y: deck.maxY), end: .zero, options: [])
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFFFFF, 0.7)); ctx.fill(CGRect(x: 0, y: deck.maxY - 1, width: W, height: 1))
    ctx.setFillColor(rgb(0x8A7650, 0.18)); ctx.fill(CGRect(x: 0, y: deck.maxY, width: W, height: 1))

    // 오른쪽 위 옅은 ※ 워터마크
    referenceMark(ctx, center: CGPoint(x: W - 58, y: y(74)), size: 150, color: rgb(0xD23B26, 0.06))

    // 제목
    text(ctx, "MHanja", font: "AppleSDGothicNeo-Bold", size: 26, color: rgb(0x2B2418), centerX: W / 2, top: 30, kern: 0.5)
    text(ctx, "자음·한글 + 트리거 키로 특수문자와 한자를 입력", font: "AppleSDGothicNeo-Medium", size: 13,
         color: rgb(0x7A6A4E), centerX: W / 2, top: 66)

    // 앱 → 응용 프로그램 화살표: 위로 볼록한 곡선을 따라 같은 간격의 점, 끝에는 곡선 방향으로 돌린 화살촉
    let red = rgb(0xD23B26, 0.85)
    let p0 = CGPoint(x: 266, y: y(200)), p2 = CGPoint(x: 390, y: y(200))
    let p1 = CGPoint(x: (p0.x + p2.x) / 2, y: p0.y + 30)
    func bezier(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                       y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
    }
    // 곡선을 잘게 나눠 길이를 재고, 같은 길이마다 점을 찍는다 (화살촉 앞에서 멈춤)
    let samples = (0...400).map { bezier(CGFloat($0) / 400) }
    var lengths: [CGFloat] = [0]
    for i in 1..<samples.count { lengths.append(lengths[i - 1] + hypot(samples[i].x - samples[i - 1].x, samples[i].y - samples[i - 1].y)) }
    let total = lengths.last!, spacing: CGFloat = 10, headGap: CGFloat = 14, dotRadius: CGFloat = 1.8
    ctx.setFillColor(red)
    var target: CGFloat = 0, i = 0
    while target <= total - headGap {
        while lengths[i] < target { i += 1 }
        let p = samples[i]
        ctx.fillEllipse(in: CGRect(x: p.x - dotRadius, y: p.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        target += spacing
    }
    // 화살촉: 끝점의 접선 방향(p1→p2)으로 돌린 V자, 굵기는 점 지름과 같게
    let angle = atan2(p2.y - p1.y, p2.x - p1.x), arm: CGFloat = 13, spread: CGFloat = .pi / 4.6
    ctx.saveGState()
    ctx.setStrokeColor(red); ctx.setLineWidth(dotRadius * 2); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: p2.x - arm * cos(angle - spread), y: p2.y - arm * sin(angle - spread)))
    ctx.addLine(to: p2)
    ctx.addLine(to: CGPoint(x: p2.x - arm * cos(angle + spread), y: p2.y - arm * sin(angle + spread)))
    ctx.strokePath()
    ctx.restoreGState()

    // 안내 문구 (받침 띠 위)
    text(ctx, "MHanja를 응용 프로그램 폴더로 끌어다 놓으세요", font: "AppleSDGothicNeo-SemiBold", size: 14,
         color: rgb(0x5C4E36), centerX: W / 2, top: 389)
}

for scale in [1, 2] {
    let ctx = CGContext(data: nil, width: Int(W) * scale, height: Int(H) * scale, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    rep.size = NSSize(width: W, height: H) // 72dpi 기준 크기 (@2x는 144dpi)
    let name = scale == 1 ? "dmg-background.png" : "dmg-background@2x.png"
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/" + name))
}
