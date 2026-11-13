import AppIntents

/// Starts a task in Qeno's chat without opening Qeno, the way a reply from Qeno's notification does.
/// When Qeno has to be in front for it (Qeno is off, or the task did not start), or Qeno is already
/// doing something, Qeno opens on the chat instead and the task under way keeps running.
struct SendTaskToPokiIntent: ForegroundContinuableIntent {
    static let title = LocalizedStringResource("Send Task to Qeno", table: "Entry")
    static let description = IntentDescription(LocalizedStringResource("Qeno starts the task on this iPhone and tells you when it is done.", table: "Entry"))
    static let openAppWhenRun = false
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
    // The Action Button and the Lock Screen work while the iPhone is locked: no task starts before it is unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: LocalizedStringResource("Task", table: "Entry"),
               requestValueDialog: IntentDialog(LocalizedStringResource("What should Qeno do?", table: "Entry")))
    var task: String

    static var parameterSummary: some ParameterSummary { Summary("Send \(\.$task) to Qeno", table: "Entry") }

    init() {}

    // Started, it ends with nothing to answer: you tapped Done once for the task, and Qeno's
    // notification says when it is done. A sentence back would wait for a second Done.
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let chat = AskQeno.chat, let app = AskQeno.app else {
            return try await showQeno(LocalizedStringResource("Qeno wasn’t ready. Try again in a moment.", table: "Entry"))
        }
        if chat.running || ChatModel.delegatedBusy != nil || app.voice.isOn {
            return try await showQeno(LocalizedStringResource("Qeno is still busy, so this task didn’t start. Here is what Qeno is doing.", table: "Entry"))
        }
        AppLog.shared.add("chat", "task from a shortcut (\(task.count) characters)")
        chat.send(task)
        guard chat.running else {
            return try await showQeno(LocalizedStringResource("Qeno couldn’t start the task. The chat says why.", table: "Entry"))
        }
        guard app.sessionOn else {
            return try await showQeno(LocalizedStringResource("Qeno started the task. Turn Qeno on so it can act on the phone.", table: "Entry"))
        }
        return .result()
    }

    @MainActor
    private func showQeno(_ words: LocalizedStringResource) async throws -> IntentResultContainer<Never, Never, Never, Never> {
        PokiEntry.shared.ask(.show)
        if #available(iOS 26.0, *) {
            try await continueInForeground(IntentDialog(words), alwaysConfirm: false)
        } else {
            throw needsToContinueInForegroundError(IntentDialog(words), continuation: nil)
        }
        return .result()
    }
}

/// Qeno's actions in Shortcuts, Spotlight and Siri, and the shortcuts the Action Button can run.
struct PokiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TalkToPokiIntent(),
                    phrases: ["Talk to \(.applicationName)", "Start talking to \(.applicationName)"],
                    shortTitle: LocalizedStringResource("Talk to Qeno", table: "Entry"), systemImageName: "waveform.circle")
        AppShortcut(intent: SendTaskToPokiIntent(),
                    phrases: ["Send a task to \(.applicationName)", "Give \(.applicationName) a task"],
                    shortTitle: LocalizedStringResource("Send Task", table: "Entry"), systemImageName: "paperplane")
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
