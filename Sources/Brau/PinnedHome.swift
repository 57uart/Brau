import AppKit

// A pinned tab's home: the page it showed when it was pinned — a pinned
// square, or a tab in a pinned group — kept so it can go back there after
// following links away, as in Dia. Double-click a pinned square, or click the
// icon of a tab in a pinned group that has wandered off (it shows a "/"), to
// go home; the tab's menu can make the page it is on the new home, or take
// one typed in.

extension Tab {
    /// Somewhere other than home. The #fragment and a trailing slash don't
    /// count: a sheet's own tabs, or a page's sections, are still home.
    var strayed: Bool {
        guard let home, let here = pending ?? address else { return false }
        return PinnedHomeURL.key(home) != PinnedHomeURL.key(here)
    }
}

enum PinnedHomeURL {
    static func key(_ url: URL) -> String {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.fragment = nil
        var text = parts?.string ?? url.absoluteString
        while text.hasSuffix("/") { text.removeLast() }
        return text.lowercased()
    }
}

extension Browser {
    /// A tab kept in place — pinned, or in a pinned group — has a home; set
    /// to where it is the moment it becomes one. Any other has none.
    func settleHomes() {
        let pinnedGroups = Set(groups.filter(\.pinned).map(\.id))
        for tab in tabs {
            let kept = tab.pin != nil || tab.group.map(pinnedGroups.contains) == true
            if kept, tab.home == nil {
                tab.home = tab.pending ?? tab.address
            } else if !kept, tab.home != nil {
                tab.home = nil
            }
        }
    }

    /// Back to the pinned page, in front.
    func goHome(_ tab: Tab) {
        guard let home = tab.home else { return }
        if activeID != tab.id { select(tab) }
        tab.go(to: home)
    }

    /// The page it is on becomes its home.
    func makeHome(_ tab: Tab) {
        guard let here = tab.address else { return }
        tab.home = here
        rememberSession()
        announce("Pinned URL replaced")
    }

    /// A home typed in.
    func editHome(_ tab: Tab) {
        let alert = NSAlert()
        alert.messageText = "Pinned URL"
        alert.informativeText = "Where “\(tab.label)” goes back to."
        let field = NSTextField(string: tab.home?.absoluteString ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn,
              let url = Address.url(from: field.stringValue.trimmingCharacters(in: .whitespaces))
        else { return }
        tab.home = url
        rememberSession()
    }
}
