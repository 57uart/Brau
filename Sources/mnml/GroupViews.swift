import AppKit
import SwiftUI

// Tab groups in the column (see Groups.swift for what a group is): a name
// with its icon, its tabs under it on a wash of its colour, folded to
// nothing or to the one tab you were on, and a list of its tabs under the
// pointer while folded.

extension TabGroup {
    /// Dia's eight: none, green, blue, purple, amber, pink, red, rust.
    static func tint(_ colour: Int) -> Color {
        switch colour {
        case 1: return Color(red: 0.20, green: 0.62, blue: 0.40)
        case 2: return Color(red: 0.16, green: 0.50, blue: 0.86)
        case 3: return Color(red: 0.45, green: 0.40, blue: 0.82)
        case 4: return Color(red: 0.86, green: 0.58, blue: 0.10)
        case 5: return Color(red: 0.86, green: 0.40, blue: 0.56)
        case 6: return Color(red: 0.86, green: 0.30, blue: 0.32)
        case 7: return Color(red: 0.86, green: 0.40, blue: 0.20)
        default: return Palette.muted
        }
    }

    var tint: Color { TabGroup.tint(colour) }
}

/// A group's icon: its emoji, a site's icon, or a small stack of tabs in
/// its colour.
struct GroupIcon: View {
    let group: TabGroup
    var size: CGFloat = 15

    var body: some View {
        switch group.icon {
        case .emoji(let emoji):
            Text(emoji).font(.system(size: size - 1)).frame(width: size, height: size)
        case .site(let host):
            if let image = Favicons.shared.cached(host) {
                Mark(icon: image, letter: "", size: size)
            } else {
                stack
            }
        case .stack:
            stack
        }
    }

    private var stack: some View {
        Image(systemName: "square.stack.fill")
            .font(.system(size: size - 3, weight: .medium))
            .foregroundStyle(group.tint.opacity(group.colour == 0 ? 0.8 : 1))
            .frame(width: size, height: size)
    }
}

/// A group in the column: its name, and under it its tabs — all of them
/// open, the one kept showing folded, or none.
struct GroupBlock<Row: View>: View {
    @ObservedObject var browser: Browser
    let group: TabGroup
    let members: [Tab]
    /// A tab's row, as the column draws it.
    let row: (Tab) -> Row
    /// The name picked up and moved: the whole group goes with it.
    let drag: (DragGesture.Value) -> Void
    let drop: () -> Void
    /// Off for the copy drawn under the hand while the group is dragged:
    /// only the group in the list says where it is.
    var reports = true

    @State private var hovering = false
    @State private var listing = false
    @State private var inList = false
    @State private var draft = ""
    @FocusState private var naming: Bool

    private var shown: [Tab] {
        if group.open { return members }
        return members.filter { $0.id == group.peek }
    }

    /// Washed in its colour while anything under the name shows, as Dia does.
    private var washed: Bool { !shown.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            ForEach(shown) { tab in
                row(tab).padding(.leading, 10)
            }
        }
        .padding(washed ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(group.tint.opacity(washed ? 0.12 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(group.tint.opacity(washed ? 0.22 : 0), lineWidth: 1)
        )
        .animation(Motion.settle, value: group.open)
        .animation(Motion.settle, value: shown.map(\.id))
    }

    private var header: some View {
        HStack(spacing: 8) {
            GroupIcon(group: group)
            if browser.renamingGroup == group.id {
                TextField("Group name", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .focused($naming)
                    .onSubmit { finishNaming() }
                    .onExitCommand { browser.renamingGroup = nil }
                    .onAppear {
                        draft = group.name
                        DispatchQueue.main.async { naming = true }
                    }
                    .onChange(of: naming) { _, focused in if !focused { finishNaming() } }
            } else {
                Text(group.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(group.colour == 0 ? Palette.ink : group.tint)
                Image(systemName: group.open ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle((group.colour == 0 ? Palette.muted : group.tint).opacity(hovering ? 1 : 0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .frame(height: 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering && !washed ? Palette.hover : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(count: 2) { browser.renamingGroup = group.id }
        .onTapGesture { withAnimation(Motion.settle) { browser.toggleOpen(group.id) } }
        .onHover { over in
            hovering = over
            peekList(over)
        }
        .modifier(Reporting(key: .header(group.id), on: reports))
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("column"))
                .onChanged { value in
                    listing = false
                    drag(value)
                }
                .onEnded { _ in drop() }
        )
        .contextMenu { GroupMenu(browser: browser, group: group) }
        .popover(isPresented: $listing, arrowEdge: .trailing) {
            GroupList(browser: browser, group: group, members: members) { inside in
                inList = inside
                if !inside { peekList(false) }
            } done: {
                listing = false
            }
        }
    }

    /// The list of a folded group's tabs, a moment after the pointer arrives
    /// on its name, gone a moment after it leaves both.
    private func peekList(_ over: Bool) {
        guard !group.open, browser.renamingGroup != group.id else { listing = false; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (over ? 0.35 : 0.3)) {
            if over, hovering { listing = true }
            if !over, !hovering, !inList { listing = false }
        }
    }

    private func finishNaming() {
        guard browser.renamingGroup == group.id else { return }
        browser.rename(group.id, to: draft)
        browser.renamingGroup = nil
    }
}

/// A folded group's tabs, from its name: a new one, and each with its ×.
private struct GroupList: View {
    @ObservedObject var browser: Browser
    let group: TabGroup
    let members: [Tab]
    let inside: (Bool) -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Quiet(icon: "plus", title: "New Tab") {
                done()
                browser.newTab(in: group.id)
            }
            ForEach(members) { tab in
                ListRow(browser: browser, tab: tab, done: done)
            }
        }
        .padding(6)
        .frame(width: 260)
        .onHover(perform: inside)
    }

    private struct ListRow: View {
        @ObservedObject var browser: Browser
        @ObservedObject var tab: Tab
        let done: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 8) {
                Mark(icon: tab.icon, letter: tab.monogram, size: 15)
                Text(tab.label)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .foregroundStyle(tab.id == browser.activeID ? Palette.ink : Palette.ink.opacity(0.8))
                Spacer(minLength: 4)
                if hovering {
                    Button { browser.close(tab) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 15, height: 15)
                            .background(Palette.ink.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tab.id == browser.activeID ? Palette.wash : (hovering ? Palette.hover : .clear))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                done()
                browser.select(tab)
            }
            .onHover { hovering = $0 }
        }
    }
}

/// A group's own menu, from its name.
struct GroupMenu: View {
    @ObservedObject var browser: Browser
    let group: TabGroup

    var body: some View {
        Button(group.pinned ? "Unpin" : "Pin") { withAnimation(Motion.settle) { browser.setPinned(group.id, !group.pinned) } }
        Divider()
        Button("New Tab in Group") { browser.newTab(in: group.id) }
        Button("Separate Tabs") { withAnimation(Motion.settle) { browser.separate(group.id) } }
        Button("Duplicate") { browser.duplicateGroup(group.id) }
        Divider()
        Button("Copy All Links") { browser.copyLinks(of: group.id) }
        Divider()
        Picker("Colour", selection: Binding(get: { group.colour }, set: { browser.setColour(group.id, $0) })) {
            ForEach(0..<TabGroup.colourCount, id: \.self) { colour in
                Label {
                    Text(TabGroup.colourName(colour))
                } icon: {
                    Image(nsImage: TabGroup.swatch(colour))
                }
                .tag(colour)
            }
        }
        Button("Rename…") { browser.renamingGroup = group.id }
        Menu("Change Icon") {
            Button("Emoji…") { GroupIconPicker.ask(browser: browser, group: group) }
            let hosts = Array(Set(browser.members(of: group.id).compactMap { ($0.pending ?? $0.address)?.host()?.lowercased() })).sorted()
            if !hosts.isEmpty {
                Divider()
                ForEach(hosts, id: \.self) { host in
                    Button {
                        browser.setIcon(group.id, .site(host))
                    } label: {
                        if let image = Favicons.shared.cached(host) {
                            Label { Text(host) } icon: { Image(nsImage: GroupIconPicker.small(image)) }
                        } else {
                            Text(host)
                        }
                    }
                }
            }
            Divider()
            Button("Use Default") { browser.setIcon(group.id, .stack) }
                .disabled(group.icon == .stack)
        }
        Divider()
        Button("Save as Bookmark Folder") { browser.saveAsBookmarks(group.id) }
        Button("Close Group") { withAnimation(Motion.settle) { browser.closeGroup(group.id) } }
    }
}

extension TabGroup {
    static func colourName(_ colour: Int) -> String {
        ["None", "Green", "Blue", "Purple", "Amber", "Pink", "Red", "Rust"][max(0, min(7, colour))]
    }

    /// A round swatch for the menu, drawn once per colour.
    static func swatch(_ colour: Int) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(TabGroup.tint(colour)).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
    }
}

/// Asking for an emoji: a small sheet with one field, and the Mac's own
/// emoji picker opened into it.
enum GroupIconPicker {
    @MainActor static func ask(browser: Browser, group: TabGroup) {
        let alert = NSAlert()
        alert.messageText = "An icon for “\(group.name)”"
        alert.informativeText = "Type or pick one emoji."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.font = .systemFont(ofSize: 16)
        if case .emoji(let current) = group.icon { field.stringValue = current }
        alert.accessoryView = field
        alert.addButton(withTitle: "Use")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        DispatchQueue.main.async { NSApp.orderFrontCharacterPalette(field) }
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        // The first character as a person sees it, however many scalars it takes.
        guard let first = field.stringValue.trimmingCharacters(in: .whitespaces).first else { return }
        browser.setIcon(group.id, .emoji(String(first)))
    }

    static func small(_ image: NSImage) -> NSImage {
        let copy = image.copy() as! NSImage
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }
}

private struct Reporting: ViewModifier {
    let key: RowKey
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.report(key) } else { content }
    }
}
