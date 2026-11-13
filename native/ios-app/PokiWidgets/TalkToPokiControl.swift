import AppIntents
import SwiftUI
import WidgetKit

/// Talk to Qeno as a control: in Control Center, on the Lock Screen and under the Action Button's
/// Controls. It runs TalkToPokiIntent, which opens Qeno.
struct TalkToPokiControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "PokiTalk") {
            ControlWidgetButton(action: TalkToPokiIntent()) {
                Label(String(localized: "Talk to Qeno", table: "Entry"), systemImage: "waveform.circle")
            }
        }
        .displayName(LocalizedStringResource("Talk to Qeno", table: "Entry"))
        .description(LocalizedStringResource("Opens Qeno and starts talking.", table: "Entry"))
    }
}
