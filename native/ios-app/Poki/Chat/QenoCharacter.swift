import SwiftUI

/// The five Qeno characters: the panda in its colourways. The choice is stored in UserDefaults
/// under `selectedCharacter` and every avatar in the app follows it; White is the default.
enum QenoCharacter: String, CaseIterable, Identifiable {
    case white, black, brown, gray, red

    var id: String { rawValue }

    /// The name in the picker.
    var name: String {
        switch self {
        case .white: String(localized: "White")
        case .black: String(localized: "Black")
        case .brown: String(localized: "Brown")
        case .gray: String(localized: "Gray")
        case .red: String(localized: "Red Panda")
        }
    }

    /// The face image in the bundle: qeno-white.png, qeno-black.png and the rest, beside PokiFace.png.
    var imageName: String { "qeno-\(rawValue)" }

    var image: UIImage? { UIImage(named: imageName) }

    /// The UserDefaults key the picker and the avatar both read.
    static let storageKey = "selectedCharacter"

    /// The stored choice, White when nothing is stored yet.
    static var stored: QenoCharacter {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey), let character = QenoCharacter(rawValue: raw) else { return .white }
            return character
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    /// The app icon this character syncs to, as the argument for setAlternateIconName. It is a
    /// double optional on purpose: outer nil means the character has no matching icon and the
    /// icon is left alone; outer .some holds the name to set, with inner nil meaning the primary
    /// (Dark) icon. White restores the primary icon, Red Panda switches to the red icon, and
    /// Black, Brown and Gray have no icon yet, so they do not touch it.
    var syncedIconName: String?? {
        switch self {
        case .white: .some(nil)
        case .red: .some("AppIcon-Red")
        case .black, .brown, .gray: nil
        }
    }

    /// Switches the home screen icon to this character's matching icon, if it has one. Failures
    /// are ignored: the character still changes even when iOS will not switch the icon.
    func syncAppIcon() {
        guard let name = syncedIconName else { return }
        UIApplication.shared.setAlternateIconName(name) { _ in }
    }
}

/// One character's face, round, at the given size: the stored image, or the white panda's face
/// (PokiFace.png), or the app icon's bear.
struct CharacterFace: View {
    var character: QenoCharacter
    var size: CGFloat

    var body: some View {
        Group {
            if let face = character.image {
                Image(uiImage: face).resizable().scaledToFill()
            } else if let face = UIImage(named: "PokiFace") {
                Image(uiImage: face).resizable().scaledToFill()
            } else {
                Image("Bear").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size).clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// The picker: the five characters in a grid, a checkmark on the one in use. Reached from the
/// Qeno details page, next to Memory.
struct CharacterPickerView: View {
    @AppStorage(QenoCharacter.storageKey) private var selectedRaw = QenoCharacter.white.rawValue

    private var selection: Binding<QenoCharacter> {
        Binding(
            get: { QenoCharacter(rawValue: selectedRaw) ?? .white },
            set: { selectedRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 16)], spacing: 20) {
                    ForEach(QenoCharacter.allCases) { character in
                        Button {
                            selection.wrappedValue = character
                            character.syncAppIcon()
                        } label: {
                            VStack(spacing: 8) {
                                CharacterFace(character: character, size: 72)
                                    .overlay(alignment: .topTrailing) {
                                        if selection.wrappedValue == character {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white, Site.blue)
                                                .background(Circle().fill(Color(.systemBackground)))
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                                Text(character.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.label))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } footer: {
                Text("Qeno's face in chats, the sessions list and the Activity Log follows this choice.")
            }
        }
        .navigationTitle("Character")
        .navigationBarTitleDisplayMode(.inline)
    }
}
