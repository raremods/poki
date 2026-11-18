import AppIntents

/// Starts a task in Qeno's chat without opening Qeno, the way a reply from Qeno's notification does.
/// When Qeno has to be in front for it (Qeno is off, or the task did not start), or Qeno is already
/// doing something, Qeno opens on the chat instead and the task under way keeps running.
/// Ordinary tasks can open the chat if they need attention. Split View tasks report an error in the
/// shortcut itself so a failed start cannot replace one of the owner's two apps.
struct SendTaskToPokiIntent: ForegroundContinuableIntent {
    private struct SplitViewStartError: LocalizedError {
        let words: LocalizedStringResource
        var errorDescription: String? { String(localized: words) }
    }

    static let title = LocalizedStringResource("Send Task to Qeno", table: "Entry")
    static let description = IntentDescription(LocalizedStringResource("Qeno starts the task and tells you when it is done.", table: "Entry"))
    static let openAppWhenRun = false
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
    // The Action Button and the Lock Screen work while the iPhone is locked: no task starts before it is unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: LocalizedStringResource("Task", table: "Entry"),
               requestValueDialog: IntentDialog(LocalizedStringResource("What should Qeno do?", table: "Entry")))
    var task: String

    @Parameter(title: LocalizedStringResource("Use Split View", table: "Entry"), default: false)
    var inSplitView: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$task) to Qeno", table: "Entry") { \.$inSplitView }
    }

    init() {}

    // Started, it ends with nothing to answer: you tapped Done once for the task, and Qeno's
    // notification says when it is done. A sentence back would wait for a second Done.
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let chat = AskQeno.chat, let app = AskQeno.app else {
            return try await needsAttention(LocalizedStringResource("Qeno wasn’t ready. Try again in a moment.", table: "Entry"))
        }
        if chat.running || ChatModel.delegatedBusy != nil || app.voice.isOn {
            let words = inSplitView ? LocalizedStringResource("Qeno is busy. Wait for the current task to finish and try again.", table: "Entry")
                : LocalizedStringResource("Qeno is still busy, so this task didn’t start. Here is what Qeno is doing.", table: "Entry")
            return try await needsAttention(words)
        }
        if inSplitView, !app.sessionOn || app.automationPath != .inProcess {
            return try await needsAttention(LocalizedStringResource("Turn on Qeno with on-device automation, then open the two apps in Split View and run the shortcut again.", table: "Entry"))
        }
        if inSplitView, !ModelKeys.hasUsableKey {
            return try await needsAttention(LocalizedStringResource("Choose a model in Qeno’s settings, then return to Split View and try again.", table: "Entry"))
        }
        AppLog.shared.add("chat", "\(inSplitView ? "Split View task" : "task") from a shortcut (\(task.count) characters)")
        chat.send(task, inSplitView: inSplitView)
        guard chat.running else {
            return try await needsAttention(LocalizedStringResource("Qeno couldn’t start the task. The chat says why.", table: "Entry"))
        }
        guard app.sessionOn else {
            return try await needsAttention(LocalizedStringResource("Qeno started the task. Turn Qeno on so it can act on the phone.", table: "Entry"))
        }
        return .result()
    }

    @MainActor
    private func needsAttention(_ words: LocalizedStringResource) async throws -> IntentResultContainer<Never, Never, Never, Never> {
        if inSplitView { throw SplitViewStartError(words: words) }
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
