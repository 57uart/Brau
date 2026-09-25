import SwiftUI

/// One Control+Tab gesture. Its candidate order stays fixed until Control is
/// released, so stepping does not rearrange the list it is stepping through.
@MainActor
final class TabSwitcher: ObservableObject {
    enum Direction { case left, right, up, down }

    private(set) var recentIDs: [Tab.ID] = []
    @Published private(set) var candidates: [Tab.ID] = []
    @Published private(set) var selectedID: Tab.ID?
    @Published private(set) var visible = false
    @Published private var previews: [Tab.ID: (address: URL, image: NSImage)] = [:]

    private var previewRequests: [Tab.ID: UUID] = [:]
    private var reveal: DispatchWorkItem?
    private var previewRequested = false
    private var generation = UUID()
    var active: Bool { !candidates.isEmpty }
    /// The other half of a tab's split, if it is in one. A split is one
    /// card, under whichever half was used last — the one it comes back to.
    var partnerOf: (Tab.ID) -> Tab.ID? = { _ in nil }

    /// The candidates and the other halves shown on their cards.
    private var shown: Set<Tab.ID> {
        Set(candidates + candidates.compactMap(partnerOf))
    }

    func record(_ id: Tab.ID) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        if recentIDs.count > 10 { recentIDs.removeLast() }
        previews = previews.filter { recentIDs.contains($0.key) }
        previewRequests = previewRequests.filter { recentIDs.contains($0.key) }
    }

    func step(eligible: [Tab.ID], current: Tab.ID, backwards: Bool) {
        if candidates.isEmpty {
            let valid = Set(eligible)
            guard valid.contains(current) else {
                ContentView.log.notice("⌃Tab ignored: the tab on screen isn't in the row")
                return
            }
            var seen: Set<Tab.ID> = []
            candidates = Array(([current] + recentIDs + eligible)
                .filter { id in
                    // A half whose other half is already a card is on it.
                    guard valid.contains(id), !seen.contains(id) else { return false }
                    if let other = partnerOf(id), seen.contains(other) { return false }
                    seen.insert(id)
                    return true
                }
                .prefix(10))
            guard candidates.count > 1 else {
                ContentView.log.notice("⌃Tab ignored: no other tab to go to")
                candidates = []
                return
            }
            selectedID = backwards ? candidates.last : candidates[1]
            let work = DispatchWorkItem { [weak self] in self?.show() }
            reveal = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
            return
        }

        guard let selectedID, let index = candidates.firstIndex(of: selectedID) else {
            // A gesture whose ⌃ let-go was never heard: start over.
            ContentView.log.notice("⌃Tab: a stale gesture was cleared")
            cancel()
            step(eligible: eligible, current: current, backwards: backwards)
            return
        }
        let next = (index + (backwards ? -1 : 1) + candidates.count) % candidates.count
        self.selectedID = candidates[next]
        show()
    }

    func move(_ direction: Direction) {
        guard let selectedID, let index = candidates.firstIndex(of: selectedID) else { return }
        show()
        let next: Int
        switch direction {
        case .left: next = (index - 1 + candidates.count) % candidates.count
        case .right: next = (index + 1) % candidates.count
        case .up:
            guard index >= 5 else { return }
            next = index - 5
        case .down:
            guard index < 5, candidates.count > 5 else { return }
            next = min(index + 5, candidates.count - 1)
        }
        self.selectedID = candidates[next]
    }

    func finish(picking id: Tab.ID? = nil) -> Tab.ID? {
        let target = id ?? selectedID
        let valid = target.flatMap { candidates.contains($0) ? $0 : nil }
        cancel()
        return valid
    }

    func cancel() {
        guard active || reveal != nil || visible else { return }
        reveal?.cancel()
        reveal = nil
        generation = UUID()
        candidates = []
        selectedID = nil
        visible = false
        previews = previews.filter { recentIDs.contains($0.key) }
        previewRequested = false
    }

    func tabsChanged(eligible: [Tab.ID]) {
        if active { cancel() }
        let valid = Set(eligible)
        recentIDs.removeAll { !valid.contains($0) }
        previews = previews.filter { valid.contains($0.key) }
        previewRequests = previewRequests.filter { valid.contains($0.key) }
    }

    /// Keep the last view of a recently used tab, without retaining its web view
    /// or writing private-page images to disk.
    func rememberPreview(of tab: Tab) {
        guard recentIDs.contains(tab.id), !tab.bench, !tab.isBlank else { return }
        requestPreview(of: tab, gesture: nil)
    }

    func forgetPreview(of id: Tab.ID) {
        previewRequests[id] = nil
        previews[id] = nil
    }

    func clearPreviews() {
        cancel()
        previewRequests = [:]
        previews = [:]
    }

    func preview(for id: Tab.ID, address: URL?) -> NSImage? {
        guard let cached = previews[id], cached.address == address else { return nil }
        return cached.image
    }

    func cachePreview(_ image: NSImage, for id: Tab.ID, address: URL) {
        guard recentIDs.contains(id) || (visible && shown.contains(id)) else { return }
        previews[id] = (address, image)
    }

    func capturePreviews(from tabs: [Tab], current: Tab.ID?) {
        guard visible, !previewRequested else { return }
        previewRequested = true
        let token = generation
        let firsts = [selectedID].compactMap { $0 } + candidates.filter { $0 != selectedID }
        let orderedIDs = firsts.flatMap { [$0] + [partnerOf($0)].compactMap { $0 } }
        // Only pictures that cost no page anything: the tab on screen, and
        // sleeping tabs, whose picture is kept. A snapshot of a live tab in
        // the background makes its page process draw — with memory short,
        // swapped back in, ten at once — and ⌃Tab froze with it.
        let ordered = orderedIDs.compactMap { id in tabs.first { $0.id == id } }
            .filter { $0.id == current || $0.built == nil }
            .filter { $0.id == current || preview(for: $0.id, address: $0.address) == nil }
        for (index, tab) in ordered.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) { [weak self, weak tab] in
                guard let self, let tab, self.generation == token, self.visible else { return }
                guard tab.id == current || self.preview(for: tab.id, address: tab.address) == nil else { return }
                self.requestPreview(of: tab, gesture: token)
            }
        }
    }

    private func requestPreview(of tab: Tab, gesture: UUID?) {
        guard let address = tab.address else { return }
        let id = tab.id
        let request = UUID()
        previewRequests[id] = request
        tab.preview(width: 180) { [weak self, weak tab] image in
            guard let self, self.previewRequests[id] == request else { return }
            self.previewRequests[id] = nil
            guard let tab, let image, tab.address == address,
                  gesture == nil || (self.generation == gesture && self.visible)
            else { return }
            self.cachePreview(image, for: id, address: address)
        }
    }

    private func show() {
        guard active, !visible else { return }
        reveal?.cancel()
        reveal = nil
        let shown = shown
        previews = previews.filter { shown.contains($0.key) }
        visible = true
    }
}

/// The switcher stays in the browser window, above its page and address field.
struct TabSwitcherOverlay: View {
    @ObservedObject var browser: Browser
    @ObservedObject var switcher: TabSwitcher
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if switcher.visible {
            GeometryReader { geometry in
                let columns = min(5, switcher.candidates.count)
                let width = min(176, (geometry.size.width - 64 - CGFloat(columns - 1) * 8) / CGFloat(columns))
                let previewHeight = (width - 16) * 0.62
                let cardHeight = previewHeight + 39
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { switcher.cancel() }

                    ZStack(alignment: .topLeading) {
                        if let selected = switcher.selectedID,
                           let index = switcher.candidates.firstIndex(of: selected) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Palette.faint)
                                .frame(width: width, height: cardHeight)
                                .offset(
                                    x: CGFloat(index % 5) * (width + 8),
                                    y: CGFloat(index / 5) * (cardHeight + 8)
                                )
                                .animation(reduceMotion ? nil : Motion.glide, value: switcher.selectedID)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<((switcher.candidates.count + 4) / 5), id: \.self) { row in
                                HStack(spacing: 8) {
                                    ForEach(Array(switcher.candidates.dropFirst(row * 5).prefix(5)), id: \.self) { id in
                                        if let tab = browser.tabs.first(where: { $0.id == id }) {
                                            card(tab, width: width, previewHeight: previewHeight, height: cardHeight)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Palette.ground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.hairline))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task(id: switcher.selectedID) {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                switcher.capturePreviews(from: browser.tabs, current: browser.activeID)
            }
        }
    }

    private func card(_ tab: Tab, width: CGFloat, previewHeight: CGFloat, height: CGFloat) -> some View {
        Button { browser.commitTabSwitch(picking: tab.id) } label: {
            VStack(spacing: 7) {
                // A split: both its pages, side by side as on screen.
                let halves = browser.split(of: tab.id).map { [$0.left, $0.right].compactMap { browser.tab($0) } } ?? [tab]
                HStack(spacing: 2) {
                    ForEach(halves) { half in
                        ZStack {
                            Palette.hover
                            if let preview = switcher.preview(for: half.id, address: half.address) {
                                PagePicture(image: preview)
                            } else {
                                Mark(icon: browser.prefs.glyph == .icons ? half.icon : nil, letter: half.monogram,
                                     size: halves.count > 1 ? 20 : 26)
                            }
                        }
                    }
                }
                .frame(width: width - 16, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                HStack(spacing: 6) {
                    ForEach(Array(halves.enumerated()), id: \.element.id) { index, half in
                        if index > 0 {
                            Rectangle()
                                .fill(Palette.hairline)
                                .frame(width: 1, height: 11)
                        }
                        HStack(spacing: 6) {
                            if browser.prefs.glyph == .icons, !half.isBlank {
                                Mark(icon: half.icon, letter: half.monogram, size: 13)
                            }
                            Text(half.label)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(width: width, height: height, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to \(tab.label)")
        .accessibilityValue(tab.id == switcher.selectedID ? "Selected" : "")
    }
}

/// A picture of a page in a frame of another shape: as wide as the frame,
/// from the page's top, the rest cut off below. The top is what a page is
/// known by — and a page from half of a split, taller than it is wide,
/// would otherwise lose it from the middle out.
struct PagePicture: View {
    let image: NSImage

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
