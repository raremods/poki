// Talk to Qeno from outside the app: the Action Button, Control Center, the Lock Screen, Shortcuts,
// Siri and Spotlight. In both the app and the widget extension, because a control's action has to be
// in both; it always runs in the app (`openAppWhenRun`).
import AppIntents
import Observation

/// What a system entry asked Qeno to show. The intent only records it; RootView takes it when its
/// scene is up, so a cold launch, Qeno in the background and Qeno in front all go the same way.
@MainActor
@Observable
final class PokiEntry {
    enum Request { case talk, show }

    static let shared = PokiEntry()
    private(set) var pending: Request?
    @ObservationIgnored private var askedAt = Date.distantPast

    func ask(_ request: Request) {
        pending = request
        askedAt = .now
    }

    /// A Talk request that waited more than a few seconds only shows the chat: the microphone starts
    /// on a press, never later on its own.
    func take() -> Request? {
        defer { pending = nil }
        if pending == .talk, Date.now.timeIntervalSince(askedAt) > 15 { return .show }
        return pending
    }
}

/// Opens Qeno's chat and starts voice there. A task Qeno is already doing is shown, not interrupted.
struct TalkToPokiIntent: AppIntent {
    static let title = LocalizedStringResource("Talk to Qeno", table: "Entry")
    static let description = IntentDescription(LocalizedStringResource("Opens Qeno and starts talking. If Qeno is doing a task, it shows that task and leaves it running.", table: "Entry"))
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PokiEntry.shared.ask(.talk)
        return .result()
    }
}
