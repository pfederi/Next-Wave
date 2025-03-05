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
                Group {
                    ThemeToggleView()
                    Divider()
                    
                    // Nearest Station Toggle
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
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notification Lead Time")
                            .font(.headline)
                        
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
                        Text("Notification Sound")
                            .font(.headline)
                            .padding(.top)
                        
                        let soundKeys = ["boat-horn", "happy", "let-the-fun-begin", "short-beep", "ukulele", "system"]
                        
                        Menu {
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
                .foregroundColor(Color("text-color"))
                
                Divider()
                
                Group {
                     Text("Information")
                        .font(.title2)
                    
                    DisclosureGroup("Safety First") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(["Keep a safe distance from the ship",
                                    "Don't ride directly behind the boat",
                                    "Be respectful to other water users",
                                    "Follow local regulations"], id: \.self) { rule in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(rule)
                                }
                            }
                        }
                        .font(.body)
                        .padding(.vertical, 8)
                    }
                    .tint(Color("text-color"))
                    
                    DisclosureGroup("How it works") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1.") + Text(" Select your spot")
                            Text("2.") + Text(" Check the timetable")
                            Text("3.") + Text(" Set notifications with a swipe from right to left")
                            Text("4.") + Text(" Enjoy your ride!")
                        }
                        .font(.body)
                        .padding(.vertical, 8)
                    }
                    .tint(Color("text-color"))
                    
                    DisclosureGroup("Features") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(["Real-time boat schedule tracking",
                                    "Smart notifications 3, 5, 10 or 15 minutes before waves",
                                    "Easy spot selection on Swiss Lakes",
                                    "Precise wave timing information",
                                    "Custom boat horn notifications"], id: \.self) { feature in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(feature)
                                }
                            }
                        }
                        .font(.body)
                        .padding(.vertical, 8)
                    }
                    .tint(Color("text-color"))

                    DisclosureGroup("Other Useful Foiling Apps") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([
                                ("7lll Water", "https://apps.apple.com/us/app/7iii-water-downwind-winging/id6495238780"),
                                ("Foil Mates", "https://apps.apple.com/ch/app/foil-mates/id6514323603"),
                                ("Foilmotion", "https://foilmotion.webchoice.ch/")
                            ], id: \.0) { app in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(app.0)
                                        .foregroundColor(.accentColor)
                                        .underline(true, color: .accentColor)
                                        .onTapGesture {
                                            if let url = URL(string: app.1) {
                                                openURL(url)
                                            }
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
                .foregroundColor(Color("text-color"))
                
                Spacer()

                Group {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://pumpfoiling.community/next-wave-app-privacy-policy/") {
                                openURL(url)
                            }
                        }) {
                            Text("Privacy Policy")
                                .font(.body)
                                .foregroundColor(.accentColor)
                                .underline(true, color: .accentColor)
                        }

                        Text("Visit pumpfoiling.community")
                            .font(.body)
                            .foregroundColor(.accentColor)
                            .underline(true, color: .accentColor)
                            .onTapGesture {
                                if let url = URL(string: "https://pumpfoiling.community") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                    .foregroundColor(Color("text-color"))
                }

                Spacer()
                
                Text("Made with 💙 by Lakeshore Studios")
                    .font(.caption)
                    .foregroundColor(Color("text-color"))
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
                
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(.caption2)
                    .foregroundColor(Color("text-color"))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Settings")
    }
} 
