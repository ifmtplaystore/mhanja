// README 스크린샷: 앱의 후보 창(CandidatePanel)과 사전 데이터로 실제 화면을 그린다.
// 직접 실행하지 말고 design/make-screenshots.sh로 만든다 → docs/screenshots/*.png

import AppKit

let outDir = CommandLine.arguments[1]
_ = NSApplication.shared

struct Shot {
    let name: String
    let prefix: String      // 이미 입력된 글자
    let composing: String   // 조합 중인 글자 (밑줄)
    let setup: (CandidatePanel) -> Void
}

func press(_ panel: CandidatePanel, _ keys: [Int64]) {
    for k in keys { _ = panel.handleKey(keyCode: k, shift: false) }
}

let down: Int64 = 125, right: Int64 = 124, tab: Int64 = 48
let symbols = SymbolTable.candidates(for: "ㅁ")
let hanja = HanjaDictionary.candidates(for: "한")!

let shots = [
    Shot(name: "symbols-list", prefix: "참고 ", composing: "ㅁ") { p in
        p.show(items: symbols, expanded: symbols, title: "ㅁ 특수문자", caret: nil)
        press(p, Array(repeating: down, count: 5))
    },
    Shot(name: "symbols-grid", prefix: "참고 ", composing: "ㅁ") { p in
        p.show(items: symbols, expanded: symbols, title: "ㅁ 특수문자", caret: nil)
        press(p, Array(repeating: down, count: 5) + [tab])
    },
    Shot(name: "hanja-list", prefix: "대", composing: "한") { p in
        p.show(items: hanja.basic, expanded: hanja.all, title: "한 한자", caret: nil)
        press(p, [down])
    },
    Shot(name: "hanja-grid", prefix: "대", composing: "한") { p in
        p.show(items: hanja.basic, expanded: hanja.all, title: "한 한자", caret: nil)
        press(p, [down, tab])
    },
]

/// 후보 창을 2배 해상도로 그린다
func render(_ view: NSView, appearance: NSAppearance) -> NSImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2),
                               pixelsHigh: Int(view.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = view.bounds.size
    appearance.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: rep) }
    let img = NSImage(size: view.bounds.size)
    img.addRepresentation(rep)
    return img
}

for dark in [false, true] {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    for shot in shots {
        let panel = CandidatePanel()
        panel.panel.appearance = appearance
        shot.setup(panel)
        let view = panel.panel.contentView!
        view.layoutSubtreeIfNeeded()
        let card = render(view, appearance: appearance)
        panel.hide()

        // 문서 위에 입력 중인 글자와 그 아래 뜬 후보 창
        let pad: CGFloat = 28, textHeight: CGFloat = 30
        let size = NSSize(width: card.size.width + pad * 2, height: card.size.height + textHeight + pad * 2)
        let canvas = NSImage(size: size, flipped: true) { _ in
            appearance.performAsCurrentDrawingAppearance {
                (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.97, alpha: 1)).setFill()
                NSRect(origin: .zero, size: size).fill()

                let font = NSFont.systemFont(ofSize: 17)
                let fg = dark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.12, alpha: 1)
                let prefix = NSAttributedString(string: shot.prefix, attributes: [.font: font, .foregroundColor: fg])
                let composing = NSAttributedString(string: shot.composing, attributes: [
                    .font: font, .foregroundColor: fg, .underlineStyle: NSUnderlineStyle.single.rawValue,
                ])
                prefix.draw(at: NSPoint(x: pad, y: pad - 4))
                let caretX = pad + prefix.size().width
                composing.draw(at: NSPoint(x: caretX, y: pad - 4))

                let shadow = NSShadow()
                shadow.shadowBlurRadius = 14
                shadow.shadowOffset = NSSize(width: 0, height: -4)
                shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.6 : 0.18)
                NSGraphicsContext.saveGraphicsState()
                shadow.set()
                card.draw(in: NSRect(x: pad, y: pad + textHeight, width: card.size.width, height: card.size.height),
                          from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        canvas.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let file = "\(outDir)/\(shot.name)\(dark ? "-dark" : "").png"
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: file))
        print(file)
    }
}
