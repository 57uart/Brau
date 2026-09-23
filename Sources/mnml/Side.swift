import SwiftUI

/// The tabs, down the left instead of across the top.
///
/// The same pieces as the strip — the grey that slides to the tab you picked,
/// the pinned squares, the cross that appears under the pointer — laid out the
/// other way. The traffic lights keep their corner; the column starts under
/// them and the page takes the whole height beside it.
struct SideBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    @Namespace private var pill

    /// What is being dragged in the list — tabs, or a whole group — how
    /// far, and where it would land (see GroupDrop).
    @State private var held: Held?
    @State private var heldY: CGFloat = 0
    @State private var gap: Int?
    /// A tab held over the middle of another long enough to make a group of the two.
    @State private var merging: Tab.ID?
    @State private var mergeCandidate: Tab.ID?
    /// Where each row is, in the list's own space.
    @State private var frames: [RowKey: CGRect] = [:]
    /// How tall the list is, for the empty column below it to drag the window.
    @State private var listHeight: CGFloat = 0

    enum Held: Equatable {
        case tabs([Tab.ID], lead: Tab.ID)
        case group(TabGroup.ID)
    }
    @State private var landing = false
    /// The width the column had when the edge was picked up.
    @State private var grabbed: CGFloat?
    @State private var onEdge = false

    /// A pin, picked up out of the grid — a separate state from the loose
    /// rows above, since the two gestures never happen at once but move on
    /// two different axes.
    @State private var pinDragging: Tab.ID?
    @State private var pinFrom = 0
    @State private var pinTravel: CGSize = .zero

    private static let row: CGFloat = 28
    private static let gap: CGFloat = 2
    private static let square: CGFloat = 34
    private static let pinGap: CGFloat = 4

    var body: some View {
        ZStack(alignment: .top) {
            // Not under the card for a new space, nor under the dots at the
            // foot: neither is made of views that would take the click first.
            DragStrip(reserved: 0, below: browser.makingSpace ? .greatestFiniteMagnitude : rowsEnd,
                      footer: prefs.usesSpaces ? 46 : 0)

            // The band the lights sit in is this mode's title bar: the window
            // is dragged by it and a double-click fills the screen with it,
            // everywhere but over the three doors, which take their own
            // clicks. The lights are the title bar's own and answer first.
            HStack(spacing: 0) {
                DragStrip()
                    .frame(width: 10 + Metrics.sideLights)
                Color.clear
                    .frame(width: Metrics.helm)
                    .allowsHitTesting(false)
                DragStrip()
            }
            .frame(height: Metrics.strip)

            VStack(alignment: .leading, spacing: 0) {
                // The traffic lights' corner, with back, forward and reload
                // sitting right of them — the same three doors as the top
                // bar, moved beside the lights since there's no far end of a
                // row to put them at in this mode.
                HStack(spacing: 0) {
                    Color.clear.frame(width: Metrics.sideLights)
                    Helm(browser: browser)
                    Spacer(minLength: 0)
                }
                .frame(height: Metrics.strip)

                // The space's rows, following two fingers sideways to the next
                // space — or, past the last, the card for a new one.
                Group {
                    if browser.makingSpace {
                        // In the middle of the column, where the rows were.
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            NewSpaceCard(browser: browser)
                            Spacer(minLength: 0)
                            Spacer(minLength: 0)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if browser.pinnedCount > 0 {
                                pinned
                                    .padding(.bottom, 10)
                            }

                            list
                        }
                        .background {
                            GeometryReader { box in
                                Color.clear
                                    .onAppear { listHeight = box.size.height }
                                    .onChange(of: box.size.height) { _, height in listHeight = height }
                            }
                        }
                    }
                }
                .offset(x: browser.spaceSwipe)
                .opacity(1 - min(0.7, abs(browser.spaceSwipe) / max(1, prefs.sideWidth)))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)

            VStack {
                Spacer()
                foot
            }
        }
        .frame(width: prefs.sideWidth)
        .frame(maxHeight: .infinity)
        // Rows on their way to or from another space stay in the column.
        .clipped()
        .onAppear { SpaceSwipe.shared.start(for: browser) }
        .background(landing ? Palette.hover : Palette.ground)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.hairline).frame(width: 1)
        }
        .overlay(alignment: .trailing) { edge }
        .onDrop(of: [.url, .text], isTargeted: $landing) { providers in
            browser.take(providers)
        }
        .animation(Motion.quick, value: landing)
        .animation(Motion.glide, value: browser.activeID)
        .animation(Motion.glide, value: browser.editingTab)
        .animation(Motion.settle, value: browser.tabs.map(\.id))
        .animation(Motion.settle, value: browser.pinnedCount)
    }

    /// The column's edge: pull it to make the column wider or narrower,
    /// double-click it to put it back. The hairline darkens under the pointer
    /// so the edge says it can be taken before it is.
    private var edge: some View {
        Rectangle()
            .fill(Palette.ink.opacity(onEdge || grabbed != nil ? 0.18 : 0))
            .frame(width: onEdge || grabbed != nil ? 2 : 1)
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { over in
                onEdge = over
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if grabbed == nil { grabbed = prefs.sideWidth }
                        let wanted = (grabbed ?? prefs.sideWidth) + value.translation.width
                        prefs.sideWidth = min(Metrics.sideMax, max(Metrics.sideMin, wanted))
                    }
                    .onEnded { _ in grabbed = nil }
            )
            .modifier(OneClick(double: true) {
                withAnimation(Motion.settle) { prefs.sideWidth = Metrics.side }
            })
            .animation(Motion.quick, value: onEdge)
    }

    /// Where the rows stop and the window's own drag area starts. Added up
    /// from what was drawn rather than measured: a measurement would arrive a
    /// frame late, and for one frame the whole column would drag the window.
    /// Where the list ends — measured, since groups fold and a line comes
    /// and goes — and the empty column below it starts.
    private var rowsEnd: CGFloat {
        Metrics.strip + listHeight + 8
    }

    // MARK: - the pinned squares

    private var pinnedTabs: [Tab] { browser.tabs.filter { $0.pin != nil } }

    /// Three columns is the block's own shape — up to six pins, that's two
    /// full rows, and one or two is just those same three places with a
    /// couple of them empty rather than a lonely row of its own width. Only
    /// past six does the block widen, one column at a time, to stay at two
    /// rows for as long as that's a reasonable shape at all.
    private static func pinColumns(_ count: Int) -> Int {
        max(3, (count + 1) / 2)
    }

    /// However many columns the count calls for, they split the row's own
    /// width between them — the row is what fills edge to edge, not each
    /// cell on its own, so this grows past 34 just as readily as it shrinks
    /// below it.
    private var pinWidth: CGFloat {
        let cols = SideBar.pinColumns(browser.pinnedCount)
        guard cols > 0 else { return SideBar.square }
        let available = prefs.sideWidth - 20 - CGFloat(cols - 1) * SideBar.pinGap
        return max(20, available / CGFloat(cols))
    }

    /// The one dimension that doesn't chase the sidebar's width: past three
    /// columns' worth of room a cell would otherwise turn into a big square
    /// rather than the wide, short button pinned tabs actually look like
    /// everywhere else in this app. It only shrinks below 34 alongside the
    /// width, once a narrow column leaves no other choice.
    private var pinHeight: CGFloat {
        min(SideBar.square, pinWidth)
    }

    /// The grid itself: fixed-size cells, left-aligned, so a half-empty last
    /// row holds its ground rather than stretching to fill it.
    private var pinned: some View {
        let tabs = pinnedTabs
        let cols = SideBar.pinColumns(tabs.count)
        let width = pinWidth
        let height = pinHeight
        // Measured in the grid's own space, not the square's: a square that
        // has just been moved to a new cell would otherwise report the drag
        // from where it now is, the target would jump back, and the square
        // would shuttle between two cells for as long as the finger stayed.
        return VStack(spacing: 0) { PinGrid(columns: cols, width: width, height: height, spacing: SideBar.pinGap) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let held = pinDragging == tab.id
                PinSquare(
                    browser: browser,
                    prefs: prefs,
                    tab: tab,
                    live: tab.id == browser.activeID,
                    pill: pill,
                    width: width,
                    height: height
                )
                .offset(pinOffset(held: held, index: index, columns: cols))
                // Under the hand exactly, as a row is (see the rows below).
                .transaction { if held { $0.animation = nil } }
                .zIndex(held ? 1 : 0)
                .shadow(color: .black.opacity(held ? 0.16 : 0), radius: 10, y: 3)
                .gesture(pinReorder(tab: tab, index: index, columns: cols, width: width, height: height))
            }
        } }
        .coordinateSpace(name: "pins")
    }

    /// The one square actually held stays glued to the fingers; every other
    /// square is already exactly where it belongs, because `browser.move`
    /// put it there — this only cancels out the bit of that same movement
    /// the held square already got for free by changing index underneath
    /// its own drag.
    private func pinOffset(held: Bool, index: Int, columns: Int) -> CGSize {
        guard held else { return .zero }
        let stepX = pinWidth + SideBar.pinGap
        let stepY = pinHeight + SideBar.pinGap
        let from = (row: pinFrom / columns, col: pinFrom % columns)
        let now = (row: index / columns, col: index % columns)
        return CGSize(
            width: pinTravel.width - CGFloat(now.col - from.col) * stepX,
            height: pinTravel.height - CGFloat(now.row - from.row) * stepY
        )
    }

    /// How many cells the drag has moved, in the grid's own row-major order
    /// — a straight line through the array a column-major offset would get
    /// wrong the moment it crossed a row. Row and column travel each measure
    /// themselves against that axis's own step now that a cell's width and
    /// height aren't the same number.
    private func pinDelta(columns: Int, stepX: CGFloat, stepY: CGFloat) -> Int {
        let col = Int((pinTravel.width / stepX).rounded())
        let row = Int((pinTravel.height / stepY).rounded())
        return row * columns + col
    }

    private func pinTarget(from: Int, moved: Int) -> Int {
        min(max(0, from + moved), max(0, pinnedTabs.count - 1))
    }

    /// Pick a square up and the others make way — across a row, and down
    /// into the next, exactly as far as the fingers actually moved.
    private func pinReorder(tab: Tab, index: Int, columns: Int, width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("pins"))
            .onChanged { value in
                if pinDragging != tab.id {
                    pinDragging = tab.id
                    pinFrom = index
                }
                pinTravel = value.translation
                let stepX = width + SideBar.pinGap
                let stepY = height + SideBar.pinGap
                let target = pinTarget(from: pinFrom, moved: pinDelta(columns: columns, stepX: stepX, stepY: stepY))
                if target != index {
                    withAnimation(Motion.settle) {
                        browser.move(tab, to: target)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(Motion.settle) {
                    pinDragging = nil
                    pinTravel = .zero
                }
            }
    }

    // MARK: - the rows

    /// A tab by itself, or a group with its tabs, in the order of the row.
    private enum Entry: Identifiable {
        case tab(Tab)
        case group(TabGroup, [Tab])
        var id: String {
            switch self {
            case .tab(let tab): return "t" + tab.id.uuidString
            case .group(let group, _): return "g" + group.id.uuidString
            }
        }
    }

    /// Above the line (pinned groups) or below it (everything else).
    private func entries(pinned: Bool) -> [Entry] {
        var out: [Entry] = []
        var seen = Set<TabGroup.ID>()
        for tab in browser.tabs where tab.pin == nil {
            if let id = tab.group, let group = browser.group(id) {
                guard group.pinned == pinned, !seen.contains(id) else { continue }
                seen.insert(id)
                out.append(.group(group, browser.members(of: id)))
            } else if !pinned {
                out.append(.tab(tab))
            }
        }
        return out
    }

    /// A line under the pinned squares and pinned groups, when there are any.
    private var hasLine: Bool { browser.pinnedCount > 0 || browser.groups.contains(where: \.pinned) }

    private var list: some View {
        let pinnedGroups = entries(pinned: true)
        return VStack(alignment: .leading, spacing: 0) {
            if !pinnedGroups.isEmpty {
                VStack(spacing: SideBar.gap) {
                    ForEach(pinnedGroups) { entry in entryView(entry) }
                }
                .padding(.bottom, 8)
            }
            if hasLine {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 6)
                    .report(.line)
                    .padding(.bottom, 8)
            }
            newTab
            VStack(spacing: SideBar.gap) {
                ForEach(entries(pinned: false)) { entry in entryView(entry) }
            }
            .padding(.top, SideBar.gap)
        }
        .coordinateSpace(name: "column")
        .onPreferenceChange(RowFrames.self) { frames = $0 }
        .overlay(alignment: .topLeading) { insertion }
        .animation(Motion.settle, value: browser.groups)
    }

    @ViewBuilder
    private func entryView(_ entry: Entry) -> some View {
        switch entry {
        case .tab(let tab):
            tabRow(tab)
        case .group(let group, let members):
            GroupBlock(browser: browser, group: group, members: members, row: { tabRow($0) },
                       drag: { value in drag(.group(group.id), value) }, drop: finishDrag)
                .offset(y: held == .group(group.id) ? heldY : 0)
                .zIndex(held == .group(group.id) ? 1 : 0)
                .shadow(color: .black.opacity(held == .group(group.id) ? 0.14 : 0), radius: 12, y: 4)
        }
    }

    private func isHeld(_ tab: Tab) -> Bool {
        if case .tabs(let ids, _)? = held { return ids.contains(tab.id) }
        return false
    }

    private func tabRow(_ tab: Tab) -> some View {
        let lifted = isHeld(tab)
        return SideRow(
            browser: browser,
            prefs: prefs,
            tab: tab,
            live: tab.id == browser.activeID,
            pill: pill,
            close: { browser.close(tab) }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Palette.ink.opacity(merging == tab.id ? 0.45 : 0), lineWidth: 1.5)
        )
        .report(.tab(tab.id))
        .offset(y: lifted ? heldY : 0)
        // Under the hand exactly; only the others glide.
        .transaction { if lifted { $0.animation = nil } }
        .zIndex(lifted ? 1 : 0)
        .shadow(color: .black.opacity(lifted ? 0.14 : 0), radius: 12, y: 4)
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("column"))
                .onChanged { value in
                    let ids = browser.chosen.contains(tab.id) ? browser.chosenTabs.map(\.id) : [tab.id]
                    drag(.tabs(ids, lead: tab.id), value)
                }
                .onEnded { _ in finishDrag() }
        )
    }

    // MARK: - dragging in the list

    /// The rows on screen, top to bottom, less whatever is being dragged.
    private func dropRows(without held: Held) -> [(row: GroupDrop.Row, key: RowKey)] {
        var out: [(GroupDrop.Row, RowKey)] = []
        func add(_ entry: Entry) {
            switch entry {
            case .tab(let tab):
                if case .tabs(let ids, _) = held, ids.contains(tab.id) { return }
                out.append((.tab(tab.id, group: nil), .tab(tab.id)))
            case .group(let group, let members):
                if held == .group(group.id) { return }
                out.append((.header(group.id, open: group.open), .header(group.id)))
                for tab in members where group.open || tab.id == group.peek {
                    if case .tabs(let ids, _) = held, ids.contains(tab.id) { continue }
                    out.append((.tab(tab.id, group: group.id), .tab(tab.id)))
                }
            }
        }
        entries(pinned: true).forEach(add)
        if hasLine { out.append((.line, .line)) }
        entries(pinned: false).forEach(add)
        return out
    }

    private func drag(_ what: Held, _ value: DragGesture.Value) {
        if held == nil { held = what }
        guard let held else { return }
        heldY = value.translation.height
        let y = value.location.y
        let rows = dropRows(without: held)
        gap = rows.filter { (frames[$0.key]?.midY ?? .infinity) < y }.count

        // Held over the middle of a tab on its own, a moment: a group of the two.
        var over: Tab.ID?
        if case .tabs = held {
            for (row, key) in rows {
                guard case .tab(let id, nil) = row, let frame = frames[key] else { continue }
                if y > frame.minY + frame.height * 0.28, y < frame.maxY - frame.height * 0.28 { over = id }
            }
        }
        guard over != mergeCandidate else { return }
        mergeCandidate = over
        merging = nil
        if let over {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if mergeCandidate == over, self.held != nil { withAnimation(Motion.quick) { merging = over } }
            }
        }
    }

    private func finishDrag() {
        defer {
            withAnimation(Motion.settle) {
                held = nil
                heldY = 0
                gap = nil
                merging = nil
                mergeCandidate = nil
            }
        }
        guard let held, let gap else { return }
        let rows = dropRows(without: held).map(\.row)
        withAnimation(Motion.settle) {
            switch held {
            case .tabs(let ids, _):
                let moving = browser.tabs.filter { ids.contains($0.id) }
                if let merging, let target = browser.tabs.first(where: { $0.id == merging }) {
                    browser.makeGroup(of: [target] + moving)
                } else {
                    browser.place(moving, GroupDrop.tab(at: gap, in: rows))
                }
            case .group(let id):
                let landing = GroupDrop.group(at: gap, in: rows)
                browser.placeGroup(id, pinned: landing.pinned, before: landing.before)
            }
        }
    }

    /// A line where the held row would land, unless it is about to make a group.
    @ViewBuilder
    private var insertion: some View {
        if let held, let gap, merging == nil {
            let rows = dropRows(without: held)
            let y: CGFloat? = gap < rows.count
                ? frames[rows[gap].key].map { $0.minY - 1 }
                : rows.last.flatMap { frames[$0.key] }.map { $0.maxY + 1 }
            if let y {
                Capsule()
                    .fill(Palette.ink.opacity(0.45))
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                    .offset(y: y - 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var newTab: some View {
        Quiet(icon: "plus", title: "New tab", height: SideBar.row) { browser.newTab() }
    }

    /// One small door at the bottom: the settings.
    private var foot: some View {
        HStack(spacing: 2) {
            if browser.prefs.usesSpaces { SpaceDots(browser: browser) }
            ExtensionSlot(edge: .trailing)
            Door(icon: "bookmark", help: "Bookmarks") { browser.bookmarksOpen.toggle() }
                .popover(isPresented: $browser.bookmarksOpen, arrowEdge: .trailing) {
                    BookmarksDropdown(browser: browser, bookmarks: browser.bookmarks)
                }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

}

/// The pinned squares' grid, every cell laid out at once. A lazy grid makes
/// its cells only once the column is on screen, where the column's slide
/// can't take them along: folded with ⌘S and brought back, the squares stood
/// in place while the column came in beneath them. A dozen squares need no
/// laziness.
private struct PinGrid: Layout {
    let columns: Int
    let width: CGFloat
    let height: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = (subviews.count + columns - 1) / columns
        return CGSize(
            width: CGFloat(columns) * width + CGFloat(max(0, columns - 1)) * spacing,
            height: CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(index % columns) * (width + spacing),
                    y: bounds.minY + CGFloat(index / columns) * (height + spacing)
                ),
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }
}

/// A pinned tab as a cell in the block at the top of the column — as wide as
/// its row asks for, but never taller than the classic square, so a row with
/// room to spare turns into a wide, short button rather than a bigger icon.
private struct PinSquare: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let live: Bool
    let pill: Namespace.ID
    var width: CGFloat = 34
    var height: CGFloat = 34

    @State private var hovering = false

    /// Everything drawn inside scales off the shorter edge — the one that
    /// stays put — so the glyph sits at its usual size, centred, rather than
    /// stretching to chase the width.
    private var scale: CGFloat { min(width, height) }

    var body: some View {
        Group {
            if browser.editingPin == tab.id {
                PinField(browser: browser, tab: tab)
            } else if prefs.glyph == .icons, let icon = tab.icon {
                Mark(icon: icon, letter: tab.pin ?? "", size: scale * 16 / 34, dim: tab.asleep)
            } else {
                Text(tab.pin ?? "")
                    .font(.system(size: scale * 12 / 34, weight: .medium))
                    .foregroundStyle((live ? Palette.ink : Palette.muted).opacity(tab.asleep ? 0.45 : 1))
            }
        }
        .frame(width: scale * 16 / 34, height: scale * 16 / 34)
        .frame(width: width, height: height)
        .background {
            if live {
                RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous)
                    .fill(Palette.wash)
                    .matchedGeometryEffect(id: "live", in: pill)
            } else {
                RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous)
                    .fill(hovering ? Palette.hover : Palette.wash.opacity(0.55))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous))
        .modifier(OneClick(double: live) {
            if live { browser.editLetter(tab) } else { browser.select(tab) }
        })
        .onHover { hovering = $0 }
        .contextMenu { TabMenu(browser: browser, tab: tab, close: { browser.close(tab) }) }
        .help(tab.label)
        .animation(Motion.quick, value: hovering)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

/// One tab, as a line in the column.
struct SideRow: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let live: Bool
    let pill: Namespace.ID
    let close: () -> Void

    @State private var hovering = false
    @State private var shake: CGFloat = 0

    private var editing: Bool { browser.editingTab == tab.id }

    var body: some View {
        HStack(spacing: 8) {
            if editing {
                TabAddressField(browser: browser)
                    .frame(height: 16)
            } else {
                if prefs.glyph == .icons, !tab.isBlank {
                    Mark(icon: tab.icon, letter: tab.monogram, size: 15)
                }
                if tab.bench {
                    // A script's tab, not yours.
                    Image(systemName: "flask")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                if tab.shy {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                Text(tab.label)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colour)
            }

            Spacer(minLength: 2)

            ZStack {
                if hovering, !editing {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 15, height: 15)
                        .background(Palette.ink.opacity(0.07), in: Circle())
                        .transition(.opacity)
                } else if tab.loading {
                    Ring().transition(.opacity)
                } else if tab.noisy {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Palette.muted)
                        .transition(.opacity)
                }
            }
            .frame(width: editing ? 0 : 15, height: 15)
            .opacity(editing ? 0 : 1)
            .overlay {
                if !editing {
                    Color.clear
                        .frame(width: 30, height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { if hovering { close() } }
                }
            }
            .animation(Motion.quick, value: hovering)
            .animation(Motion.quick, value: tab.loading)
            .animation(Motion.quick, value: tab.noisy)
        }
        .padding(.leading, 10)
        .padding(.trailing, editing ? 10 : 7)
        .frame(height: 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ground }
        .modifier(Shake(travel: shake))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .modifier(OneClick(double: false) {
            // ⌘-click picks tabs, ⇧-click a run of them, for the menu to act
            // on together; a plain click is the tab, and lets the pick go.
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) { browser.toggleChosen(tab); return }
            if flags.contains(.shift) { browser.chooseRange(to: tab); return }
            browser.chosen = []
            if live { browser.beginTabEdit(tab) } else { browser.select(tab) }
        })
        .onHover { hovering = $0 }
        .contextMenu { TabMenu(browser: browser, tab: tab, close: close) }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.glide, value: editing)
        .onChange(of: browser.refusals) { _, _ in
            guard editing else { return }
            shake = 0
            withAnimation(.easeOut(duration: 0.5)) { shake = 1 }
        }
        .transition(.scale(scale: 0.94, anchor: .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var ground: some View {
        if live {
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.wash)
                GeometryReader { geo in
                    Rectangle()
                        .fill(Palette.ink.opacity(0.055))
                        .frame(width: geo.size.width * tab.reading)
                        .animation(.easeOut(duration: 0.15), value: tab.reading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .matchedGeometryEffect(id: "live", in: pill)
        } else if browser.chosen.contains(tab.id) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.wash)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Palette.ink.opacity(0.18), lineWidth: 1)
                )
        } else if hovering {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.hover)
        }
    }

    private var colour: Color {
        if live { return Palette.ink }
        return hovering ? Palette.ink.opacity(0.7) : Palette.muted
    }
}

/// A row that is an action rather than a page. Quiet until the pointer is on it.
struct Quiet: View {
    let icon: String
    let title: String
    var height: CGFloat = 28
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 12.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(hovering ? Palette.ink.opacity(0.7) : Palette.faint)
            .padding(.leading, 10)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Palette.hover : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// A small square holding one symbol. Lit when what it opens is open.
struct Door: View {
    let icon: String
    var on = false
    var help = ""
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? Palette.ink : (hovering ? Palette.ink.opacity(0.7) : Palette.muted))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Palette.wash : (hovering ? Palette.hover : .clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: on)
    }
}

/// A row's place in the column's list, reported for dragging (see SideBar).
enum RowKey: Hashable {
    case tab(UUID)
    case header(UUID)
    case line
}

struct RowFrames: PreferenceKey {
    static var defaultValue: [RowKey: CGRect] = [:]
    static func reduce(value: inout [RowKey: CGRect], nextValue: () -> [RowKey: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Where this row is, in the list's space.
    func report(_ key: RowKey) -> some View {
        background(GeometryReader { box in
            Color.clear.preference(key: RowFrames.self, value: [key: box.frame(in: .named("column"))])
        })
    }
}
