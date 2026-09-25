import Foundation
@_weakLinked import FoundationModels

// A new group's name, from its tabs, by the Mac's own model (Apple
// Intelligence, macOS 26 and later). On this Mac, nothing sent anywhere.
// Without the model — an older macOS, Apple Intelligence off, a language it
// doesn't speak — there is no name, and the group is named as before.

enum GroupNamer {
    /// Whether a name can be asked for at all, so the field to type one
    /// needn't open while it is on its way.
    static var available: Bool {
        guard #available(macOS 26, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    /// Two or three words for what the tabs have in common.
    static func name(for tabs: [(title: String, site: String)]) async -> String? {
        guard #available(macOS 26, *), SystemLanguageModel.default.isAvailable, !tabs.isEmpty else { return nil }
        let list = tabs.prefix(12).map { "- \($0.title) (\($0.site))" }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You name groups of browser tabs. Reply with the name only: one to \
            three words, Title Case, no quotes, no punctuation, no emoji. One \
            phrase for what the tabs share (a topic, a task, a project), never \
            a list of what each one is, and never the word "tabs". Be specific: \
            keep the place, product or project they name. If the tabs share no one \
            subject, name the broader field they have in common, not the largest part.
            """)
        guard let reply = try? await session.respond(to: "Tabs:\n\(list)").content else { return nil }
        return tidy(reply)
    }

    /// The model's reply as a name: first line, no quotes or trailing
    /// stop, three words at most. Nil for anything that isn't one.
    static func tidy(_ reply: String) -> String? {
        let line = reply.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let bare = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’`*.:").union(.whitespaces))
        // A list, or a name and a subtitle, the model gave anyway: the first part.
        guard let first = bare.split(whereSeparator: { $0 == "," || $0 == ":" }).first else { return nil }
        let words = first.split(separator: " ").prefix(3).joined(separator: " ")
        guard !words.isEmpty, words.count <= 30 else { return nil }
        return words
    }
}

import SwiftUI

/// A group's name while the Mac's model writes it — dimmed, a light passing
/// over it — and as the name comes: in colour, the colour running off to
/// the right and leaving it in ink, as Dia does.
struct NameGlow: ViewModifier {
    let naming: Bool
    let arrived: Bool
    @State private var shimmer: CGFloat = 0
    @State private var reveal: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .opacity(naming ? 0.45 : 1)
            .blur(radius: arrived ? 2.5 * (1 - reveal) : 0)
            .overlay {
                if naming || arrived {
                    GeometryReader { geo in
                        let w = max(geo.size.width, 1)
                        LinearGradient(stops: naming ? NameGlow.light : NameGlow.colours,
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: w * 2)
                            // The light crosses from before the name to past
                            // it; the colours start on it and leave rightwards.
                            .offset(x: naming ? (shimmer * 3 - 2) * w : (reveal * 2 - 1) * w)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { if naming { startShimmer() } }
            .onChange(of: naming) { _, on in
                if on { startShimmer() } else {
                    // The light stops with the naming, not somewhere unseen.
                    var still = Transaction(); still.disablesAnimations = true
                    withTransaction(still) { shimmer = 0 }
                }
            }
            .onChange(of: arrived) { _, on in
                guard on else { return }
                reveal = 0
                withAnimation(.easeOut(duration: 1.0)) { reveal = 1 }
            }
    }

    private func startShimmer() {
        shimmer = 0
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { shimmer = 1 }
    }

    private static let light: [Gradient.Stop] = [
        .init(color: .clear, location: 0.3),
        .init(color: .white.opacity(0.9), location: 0.5),
        .init(color: .clear, location: 0.7),
    ]
    private static let colours: [Gradient.Stop] = [
        .init(color: .clear, location: 0.35),
        .init(color: Color(red: 0.45, green: 0.65, blue: 1.0), location: 0.5),
        .init(color: Color(red: 1.0, green: 0.82, blue: 0.45), location: 0.72),
        .init(color: Color(red: 1.0, green: 0.45, blue: 0.85), location: 0.92),
    ]
}
