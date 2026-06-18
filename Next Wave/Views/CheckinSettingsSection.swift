import SwiftUI

// MARK: - Wave Check-in Settings Section

struct CheckinSettingsSection: View {
    @ObservedObject var appSettings: AppSettings
    @State private var showIdentitySheet = false

    private var identityLabel: String {
        if appSettings.checkinAnonymous { return "Anonymous" }
        let name = appSettings.checkinName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Not set" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wave Check-in")
                .font(.headline)

            Toggle(isOn: $appSettings.enableWaveCheckIn) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Wave Check-ins")
                            .foregroundColor(Color("text-color"))
                            .font(.system(size: 17, weight: .regular))
                        Text("See how many foilers plan to ride each wave")
                            .foregroundColor(Color("text-color").opacity(0.7))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            if appSettings.enableWaveCheckIn {
                Button(action: { showIdentitySheet = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(Color("text-color"))
                            .font(.system(size: 20))
                            .padding(.trailing, 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check-in Name")
                                .foregroundColor(Color("text-color"))
                                .font(.system(size: 17, weight: .regular))
                            Text(identityLabel)
                                .foregroundColor(Color("text-color").opacity(0.7))
                                .font(.system(size: 14))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(Color("text-color").opacity(0.5))
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .sheet(isPresented: $showIdentitySheet) {
                    CheckinIdentitySheet().environmentObject(appSettings)
                }
            }
        }
        .foregroundColor(Color("text-color"))
    }
}

// MARK: - Check-in Identity Sheet

struct CheckinIdentitySheet: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Called after the user saves a valid identity (used to chain a pending check-in).
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var anonymous: Bool = false

    private var canSave: Bool {
        anonymous || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Your name", text: $name)
                        .disabled(anonymous)
                    Toggle("Join anonymously", isOn: $anonymous)
                } footer: {
                    Text("Your name is visible to other foilers on this wave. Choose anonymous to be counted without a name. See our privacy policy for details.")
                }

                Section {
                    Button("Privacy Policy") {
                        if let url = URL(string: "https://www.nextwaveapp.ch/privacy") {
                            openURL(url)
                        }
                    }
                }
            }
            .navigationTitle("How others see you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appSettings.checkinName = name
                        appSettings.checkinAnonymous = anonymous
                        // Sync the leaderboard name immediately (sets nil when anonymous/blank).
                        let displayName = CheckinIdentity(name: name, isAnonymous: anonymous).displayName
                        Task { await CheckinAPI.shared.syncProfileName(displayName) }
                        onSave?()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                name = appSettings.checkinName.isEmpty
                    ? UIDevice.current.name
                    : appSettings.checkinName
                anonymous = appSettings.checkinAnonymous
            }
        }
    }
}
