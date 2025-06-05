import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var audioPlayer: AVAudioPlayer?
    
    let availableLeadTimes = [3, 5, 10, 15]
    
    private func playSound(_ soundName: String) {
        if let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") {
            audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme section
                ThemeToggleView()
                Divider()
                
                // Display options section
                DisplayOptionsSection(appSettings: appSettings)
                
                Divider()
                
                // Widget section
                WidgetSettingsSection(appSettings: appSettings)
                
                Divider()
                
                // Notification section
                NotificationSettingsSection(
                    scheduleViewModel: scheduleViewModel,
                    availableLeadTimes: availableLeadTimes,
                    playSound: playSound
                )
                
                Divider()
                
                // Information section
                InformationSection(openURL: openURL)
                
                Spacer()

                // Links section
                LinksSection(openURL: openURL)

                Spacer()
                
                // Footer section
                FooterSection(openURL: openURL)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Settings")
    }
}

// MARK: - Widget Settings Section
struct WidgetSettingsSection: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch Settings")
                .font(.headline)
            
            Toggle(isOn: $appSettings.useNearestStationForWidget) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Nearest Station")
                            .foregroundColor(Color("text-color"))
                            .font(.system(size: 17, weight: .regular))
                        Text("Show nearest station in widget and on top of favorites in Watch App")
                            .foregroundColor(Color("text-color").opacity(0.7))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .foregroundColor(Color("text-color"))
    }
}

// MARK: - Display Options Section
struct DisplayOptionsSection: View {
    @ObservedObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Options")
                .font(.headline)
            
            Toggle(isOn: $appSettings.showNearestStation) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)
                    
                    Text("Show Nearest Station")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 17, weight: .regular))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Toggle(isOn: $appSettings.showWeatherInfo) {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)
                    
                    Text("Show Weather Information")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 17, weight: .regular))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .foregroundColor(Color("text-color"))
    }
}

// MARK: - Notification Settings Section
struct NotificationSettingsSection: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let availableLeadTimes: [Int]
    let playSound: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notification Lead Time")
                .font(.headline)
            
            LeadTimeMenu(
                scheduleViewModel: scheduleViewModel,
                availableLeadTimes: availableLeadTimes
            )
            
            Text("Notification Sound")
                .font(.headline)
                .padding(.top)
            
            SoundMenu(
                scheduleViewModel: scheduleViewModel,
                playSound: playSound
            )
        }
        .foregroundColor(Color("text-color"))
    }
}

struct LeadTimeMenu: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let availableLeadTimes: [Int]
    
    var body: some View {
        Menu {
            ForEach(availableLeadTimes, id: \.self) { time in
                Button(action: {
                    scheduleViewModel.updateLeadTime(time)
                }) {
                    HStack {
                        Text("\(time) minutes")
                        if scheduleViewModel.settings.leadTime == time {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(Color("text-color"))
                    .font(.system(size: 20))
                    .padding(.trailing, 8)
                
                Text("\(scheduleViewModel.settings.leadTime) minutes")
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

struct SoundMenu: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let playSound: (String) -> Void
    
    var body: some View {
        let soundKeys = ["boat-horn", "happy", "let-the-fun-begin", "short-beep", "ukulele", "system"]
        
        return Menu {
            ForEach(soundKeys, id: \.self) { key in
                Button(action: {
                    scheduleViewModel.updateSound(key)
                    if key != "system" {
                        playSound(key)
                    }
                }) {
                    HStack {
                        Text(scheduleViewModel.availableSounds[key] ?? "")
                        if scheduleViewModel.settings.selectedSound == key {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(Color("text-color"))
                    .font(.system(size: 20))
                    .padding(.trailing, 8)
                
                Text(scheduleViewModel.availableSounds[scheduleViewModel.settings.selectedSound] ?? "")
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

// MARK: - Information Section
struct InformationSection: View {
    let openURL: OpenURLAction
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Information")
                .font(.title2)
            
            SafetySection(openURL: openURL)
            
            HowItWorksSection()
                
            FeaturesSection()

            OtherAppsSection(openURL: openURL)
        }
        .foregroundColor(Color("text-color"))
    }
}

struct SafetySection: View {
    let openURL: OpenURLAction
    
    var body: some View {
        DisclosureGroup("Safety First") {
            VStack(alignment: .leading, spacing: 8) {
                SafetyRuleView(rule: "Keep a safe distance from the ship")
                SafetyRuleView(rule: "Don't ride directly behind the boat")
                SafetyRuleView(rule: "Be respectful to other water users")
                SafetyRuleView(rule: "Follow local regulations")
                
                HStack {
                    Text("We support the")
                    
                    Button(action: {
                        if let url = URL(string: "https://responsible.pumpfoiling.community") {
                            openURL(url)
                        }
                    }) {
                        Text("Pumpfoilers Code of Conduct")
                            .foregroundColor(.accentColor)
                            .underline(true, color: .accentColor)
                    }
                }
            }
            .font(.body)
            .padding(.vertical, 8)
        }
        .tint(Color("text-color"))
    }
}

struct HowItWorksSection: View {
    var body: some View {
        DisclosureGroup("How it works") {
            VStack(alignment: .leading, spacing: 8) {
                StepView(number: 1, text: "Select your station")
                StepView(number: 2, text: "Check the timetable")
                StepView(number: 3, text: "Set notifications with a swipe from right to left")
                StepView(number: 4, text: "Enjoy your ride!")
            }
            .font(.body)
            .padding(.vertical, 8)
        }
        .tint(Color("text-color"))
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack {
            Text("\(number).")
            Text(text)
        }
    }
}

struct FeaturesSection: View {
    let features = [
        "Real-time boat schedule tracking",
        "Smart notifications 3, 5, 10 or 15 minutes before waves",
        "Easy station selection on Swiss Lakes",
        "Precise wave timing information",
        "Custom boat horn notifications"
    ]
    
    var body: some View {
        DisclosureGroup("Features") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    SafetyRuleView(rule: feature)
                }
            }
            .font(.body)
            .padding(.vertical, 8)
        }
        .tint(Color("text-color"))
    }
}

struct OtherAppsSection: View {
    let openURL: OpenURLAction
    let apps = [
        ("7lll Water", "https://apps.apple.com/us/app/7iii-water-downwind-winging/id6495238780"),
        ("Foil Mates", "https://apps.apple.com/ch/app/foil-mates/id6514323603"),
        ("Foilmotion", "https://foilmotion.webchoice.ch/"),
        ("Foile", "https://foile.ch/")
    ]
    
    var body: some View {
        DisclosureGroup("Other Useful Foiling Apps") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(apps, id: \.0) { app in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Button(action: {
                            if let url = URL(string: app.1) {
                                openURL(url)
                            }
                        }) {
                            Text(app.0)
                                .foregroundColor(.accentColor)
                                .underline(true, color: .accentColor)
                        }
                    }
                }
            }
            .font(.body)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(Color("text-color"))
    }
}

// MARK: - Links Section
struct LinksSection: View {
    let openURL: OpenURLAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                if let url = URL(string: "https://nextwaveapp.ch/privacy.html") {
                    openURL(url)
                }
            }) {
                Text("Privacy Policy")
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .underline(true, color: .accentColor)
            }

            Button(action: {
                if let url = URL(string: "https://pumpfoiling.community") {
                    openURL(url)
                }
            }) {
                Text("Visit pumpfoiling.community")
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .underline(true, color: .accentColor)
            }
        }
        .foregroundColor(Color("text-color"))
    }
}

// MARK: - Footer Section
struct FooterSection: View {
    let openURL: OpenURLAction
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                Text("Made with 💙 by ")
                    .font(.caption)
                    .foregroundColor(Color("text-color"))
                    .opacity(0.8)
                
                Button(action: {
                    if let url = URL(string: "https://lakeshorestudios.ch") {
                        openURL(url)
                    }
                }) {
                    Text("Lakeshore Studios")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .underline(true, color: .accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 4)
            
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.caption2)
                .foregroundColor(Color("text-color"))
                .opacity(0.6)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Supporting Views
struct SafetyRuleView: View {
    let rule: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(rule)
        }
    }
} 
