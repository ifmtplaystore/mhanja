import AppKit

/// 포커스를 빼앗지 않는 후보 목록 창 (한 페이지 9개).
/// 펼칠 목록(expanded)이 있으면 Tab으로 전체 문자를 격자로 펼쳐 볼 수 있다.
final class CandidatePanel {
    static let pageSize = 9
    static let gridColumns = 10
    static let gridMaxRows = 10

    var onSelect: ((String) -> Void)?

    private let panel: NSPanel
    private let view = CandidateView()
    private var listItems: [Candidate] = []
    /// 펼친 목록. listItems로 시작해야 한다(펼치고 접을 때 선택 위치를 그대로 쓴다).
    private var gridItems: [Candidate]?
    private var selected = 0
    private var expanded = false
    private var topRow = 0
    private var title = ""
    private var anchor: NSRect = .zero

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = view
        view.onClick = { [weak self] index in self?.pick(index: index) }
    }

    private var items: [Candidate] { expanded ? gridItems ?? listItems : listItems }
    private var page: Int { selected / Self.pageSize }
    private var pageCount: Int { (listItems.count + Self.pageSize - 1) / Self.pageSize }

    func show(items: [Candidate], expanded: [Candidate]?, title: String, caret: NSRect?) {
        listItems = items
        gridItems = expanded
        selected = 0
        self.expanded = false
        topRow = 0
        self.title = title
        anchor = caret ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        refresh()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// 후보 창이 떠 있을 때의 키 입력 처리. 처리했으면 true.
    func handleKey(keyCode: Int64, shift: Bool) -> Bool {
        if expanded { return handleGridKey(keyCode: keyCode) }
        switch keyCode {
        case 53: // Esc
            hide()
        case 126: // ↑
            move(to: selected - 1)
        case 125: // ↓
            move(to: selected + 1)
        case 123, 116: // ←, PageUp
            move(to: (page - 1) * Self.pageSize)
        case 124, 121: // →, PageDown
            move(to: (page + 1) * Self.pageSize)
        case 48: // Tab: 펼칠 목록이 있으면 펼치기, 없으면 페이지 이동
            if gridItems != nil && !shift {
                expanded = true
                refresh()
            } else {
                move(to: (page + (shift ? -1 : 1)) * Self.pageSize)
            }
        case 36, 76: // Return, Enter
            pick(index: selected)
        default:
            guard let n = Self.digit(keyCode) else { return false }
            pick(index: page * Self.pageSize + n - 1, withinPage: true)
        }
        return true
    }

    private func handleGridKey(keyCode: Int64) -> Bool {
        let cols = Self.gridColumns
        switch keyCode {
        case 53: // Esc
            hide()
        case 48: // Tab: 목록으로 되돌리기 (기본 목록 밖의 글자를 고르고 있었다면 처음으로)
            expanded = false
            if selected >= listItems.count { selected = 0 }
            refresh()
        case 123: // ←
            move(to: selected - 1)
        case 124: // →
            move(to: selected + 1)
        case 126: // ↑ (같은 열에서 순환)
            moveVertically(by: -cols)
        case 125: // ↓
            moveVertically(by: cols)
        case 116: // PageUp
            selected = max(selected - cols * Self.gridMaxRows, 0)
            refresh()
        case 121: // PageDown
            selected = min(selected + cols * Self.gridMaxRows, items.count - 1)
            refresh()
        case 36, 76: // Return, Enter
            pick(index: selected)
        default:
            return false
        }
        return true
    }

    private static func digit(_ keyCode: Int64) -> Int? {
        let main: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        let pad: [Int64] = [83, 84, 85, 86, 87, 88, 89, 91, 92]
        if let i = main.firstIndex(of: keyCode) ?? pad.firstIndex(of: keyCode) { return i + 1 }
        return nil
    }

    private func move(to index: Int) {
        guard !items.isEmpty else { return }
        // 처음/끝에서 반대쪽으로 순환
        selected = (index % items.count + items.count) % items.count
        refresh()
    }

    private func moveVertically(by delta: Int) {
        let next = selected + delta
        if next >= 0 && next < items.count {
            selected = next
        } else {
            // 위/아래 끝을 넘으면 같은 열의 반대쪽 끝으로
            let col = selected % Self.gridColumns
            let lastRow = (items.count - 1) / Self.gridColumns
            if delta < 0 {
                let target = lastRow * Self.gridColumns + col
                selected = target < items.count ? target : target - Self.gridColumns
            } else {
                selected = col
            }
        }
        refresh()
    }

    private func pick(index: Int, withinPage: Bool = false) {
        guard index >= 0, index < items.count else { return }
        if withinPage, index / Self.pageSize != page { return }
        hide()
        onSelect?(items[index].text)
    }

    private func refresh() {
        if expanded {
            let cols = Self.gridColumns, maxRows = Self.gridMaxRows
            let totalRows = (items.count + cols - 1) / cols
            // 선택한 줄이 보이도록 스크롤
            let row = selected / cols
            if row < topRow { topRow = row }
            if row >= topRow + maxRows { topRow = row - maxRows + 1 }
            let start = topRow * cols
            view.mode = .grid(columns: cols, rows: min(totalRows, maxRows))
            view.rows = Array(items[start..<min(start + cols * maxRows, items.count)])
            view.firstIndex = start
            view.highlighted = selected - start
            let note = items[selected].note
            view.title = note.isEmpty ? title : "\(title) · \(note)"
            view.footer = "←↑↓→ 이동 · Enter 선택 · Tab 목록"
            view.pageLabel = totalRows > maxRows ? "\(row + 1)/\(totalRows)줄" : ""
        } else {
            let start = page * Self.pageSize
            // 설명(훈)이 없는 목록(특수문자)은 글자만 들어가므로 좁게
            let compact = listItems.allSatisfy { $0.note.isEmpty }
            view.mode = .list(compact: compact)
            view.rows = Array(listItems[start..<min(start + Self.pageSize, listItems.count)])
            view.firstIndex = start
            view.highlighted = selected - start
            view.title = title
            view.footer = gridItems == nil ? "Tab/←→ 페이지" : compact ? "Tab 전체" : "Tab 전체 보기 · ←→ 페이지"
            view.pageLabel = "\(page + 1)/\(pageCount)"
        }
        view.needsDisplay = true
        layout()
    }

    /// 캐럿 아래(공간이 없으면 위)에 창을 놓고 화면 안으로 맞춘다.
    private func layout() {
        let size = view.preferredSize
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var origin = NSPoint(x: anchor.minX, y: anchor.minY - size.height - 4)
        if origin.y < visible.minY { origin.y = anchor.maxY + 4 }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)

        let frame = NSRect(origin: origin, size: size)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }
}

private final class CandidateView: NSView {
    enum Mode: Equatable { case list(compact: Bool), grid(columns: Int, rows: Int) }

    var mode: Mode = .list(compact: false)
    var title = ""
    var rows: [Candidate] = []
    /// rows[0]의 전체 목록 기준 인덱스 (클릭 시 되돌려줌)
    var firstIndex = 0
    var highlighted = 0
    var footer = ""
    var pageLabel = ""
    var onClick: ((Int) -> Void)?

    private let rowHeight: CGFloat = 28
    private let cellSize: CGFloat = 34
    private let gridInset: CGFloat = 8
    private let headerHeight: CGFloat = 22
    private let footerHeight: CGFloat = 22

    var preferredSize: NSSize {
        switch mode {
        case .list(let compact):
            return NSSize(width: compact ? 130 : 260, height: headerHeight + rowHeight * CGFloat(CandidatePanel.pageSize) + footerHeight)
        case .grid(let cols, let gridRows):
            return NSSize(width: gridInset * 2 + cellSize * CGFloat(cols),
                          height: headerHeight + cellSize * CGFloat(max(1, gridRows)) + footerHeight)
        }
    }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var small: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.windowBackgroundColor.setFill()
        bg.fill()
        NSColor.separatorColor.setStroke()
        bg.stroke()

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: NSRect(x: 10, y: 4, width: bounds.width - 20, height: 16),
                                 withAttributes: small.merging([.paragraphStyle: titleStyle]) { $1 })

        switch mode {
        case .list: drawList()
        case .grid(let cols, _): drawGrid(columns: cols)
        }

        let fy = bounds.height - footerHeight + 4
        let w = (pageLabel as NSString).size(withAttributes: small).width
        (pageLabel as NSString).draw(at: NSPoint(x: bounds.width - w - 10, y: fy), withAttributes: small)
        (footer as NSString).draw(at: NSPoint(x: 10, y: fy), withAttributes: small)
    }

    private func drawList() {
        for (i, row) in rows.enumerated() {
            let rect = NSRect(x: 4, y: headerHeight + CGFloat(i) * rowHeight, width: bounds.width - 8, height: rowHeight)
            let isSel = i == highlighted
            if isSel {
                NSColor.selectedContentBackgroundColor.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
            }
            let fg: NSColor = isSel ? .alternateSelectedControlTextColor : .labelColor
            let sub: NSColor = isSel ? .alternateSelectedControlTextColor : .secondaryLabelColor

            ("\(i + 1)" as NSString).draw(at: NSPoint(x: rect.minX + 8, y: rect.minY + 6),
                                          withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular), .foregroundColor: sub])
            (row.text as NSString).draw(at: NSPoint(x: rect.minX + 32, y: rect.minY + 2),
                                        withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: fg])
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let noteRect = NSRect(x: rect.minX + 66, y: rect.minY + 7, width: rect.maxX - rect.minX - 74, height: 16)
            (row.note as NSString).draw(in: noteRect, withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: sub, .paragraphStyle: style])
        }
    }

    private func drawGrid(columns cols: Int) {
        // 선택 칸은 나머지를 다 그린 뒤 1.7배로 키워 맨 위에 그린다 (이웃 칸을 덮는다)
        for (i, cell) in rows.enumerated() where i != highlighted {
            drawCell(cell.text, in: cellRect(i, columns: cols), fontSize: 18, selected: false)
        }
        guard rows.indices.contains(highlighted) else { return }
        let scale: CGFloat = 1.7
        let cell = cellRect(highlighted, columns: cols)
        var rect = cell.insetBy(dx: -cell.width * (scale - 1) / 2, dy: -cell.height * (scale - 1) / 2)
        // 창 크기는 그대로 두고, 가장자리 칸이면 확대한 칸을 격자 영역 안으로 밀어 넣는다
        // (제목 줄의 훈과 아래 안내를 가리지 않게; 격자가 한 줄뿐이면 창 안으로만)
        let gridArea = NSRect(x: 2, y: headerHeight, width: bounds.width - 4,
                              height: bounds.height - headerHeight - footerHeight)
        let area = rect.height <= gridArea.height ? gridArea : bounds.insetBy(dx: 2, dy: 2)
        rect.origin.x = min(max(rect.minX, area.minX), area.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, area.minY), area.maxY - rect.height)
        drawCell(rows[highlighted].text, in: rect, fontSize: 18 * scale, selected: true)
    }

    private func drawCell(_ text: String, in rect: NSRect, fontSize: CGFloat, selected: Bool) {
        if selected {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 6
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.set()
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor,
            .paragraphStyle: style,
        ]
        let h = (text as NSString).size(withAttributes: attrs).height
        (text as NSString).draw(in: NSRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h),
                                withAttributes: attrs)
    }

    private func cellRect(_ i: Int, columns cols: Int) -> NSRect {
        NSRect(x: gridInset + CGFloat(i % cols) * cellSize, y: headerHeight + CGFloat(i / cols) * cellSize,
               width: cellSize, height: cellSize)
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard p.y >= headerHeight else { return }
        switch mode {
        case .list:
            let row = Int((p.y - headerHeight) / rowHeight)
            if row < rows.count { onClick?(firstIndex + row) }
        case .grid(let cols, _):
            guard p.x >= gridInset else { return }
            let col = Int((p.x - gridInset) / cellSize), row = Int((p.y - headerHeight) / cellSize)
            let i = row * cols + col
            if col < cols, i < rows.count { onClick?(firstIndex + i) }
        }
    }
}
