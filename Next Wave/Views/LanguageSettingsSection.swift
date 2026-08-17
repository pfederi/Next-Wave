import SwiftUI

struct LanguageSettingsSection: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language")
                .font(.headline)

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        appSettings.language = language
                    }) {
                        HStack {
                            label(for: language)
                            if appSettings.language == language {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)

                    label(for: appSettings.language)
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 17, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("text-color").opacity(0.3), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `.system`'s label is translated ("System"/"Système"/...); every other
    /// language's own name is shown verbatim, in its own script, regardless of
    /// the app's current display language — so it never goes through Text's
    /// LocalizedStringKey lookup.
    private func label(for language: AppLanguage) -> Text {
        if let nativeName = language.nativeName {
            return Text(verbatim: nativeName)
        }
        return Text("System")
    }
}
