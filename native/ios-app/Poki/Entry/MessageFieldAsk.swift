import Observation

/// A system entry asked for the message field with the keyboard up. ChatView takes it once it is on
/// screen, so a cold launch, where the chat appears after the request, goes the same way as Qeno in front.
/// An ask can carry the words to put in the field already (the first run's "What to Try" examples).
@MainActor
@Observable
final class MessageFieldAsk {
    static let shared = MessageFieldAsk()
    private(set) var pending = false
    /// The words an ask carries for the message field, when one was asked with them.
    private(set) var text: String?

    func ask() { text = nil; pending = true }

    /// Ask for the message field with these words already in it.
    func ask(text: String) { self.text = text; pending = true }

    func take() -> Bool {
        defer { pending = false }
        return pending
    }

    /// Take the ask and the words it carries, if any; clears both.
    func takeText() -> String? {
        defer { pending = false; text = nil }
        return text
    }
}
