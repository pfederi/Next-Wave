import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("notificationLeadTime") private var leadTime: Int = 5
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
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
                // Neue Settings Section
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notification Lead Time")
                            .font(.headline)
                        
                        Menu {
                            ForEach(availableLeadTimes, id: \.self) { time in
                                Button(action: {
                                    DispatchQueue.main.async {
                                        leadTime = time
                                    }
                                }) {
                                    HStack {
                                        Text("\(time) minutes")
                                        if leadTime == time {
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
                                
                                Text("\(leadTime) minutes")
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
                        
                        Divider()
                            .padding(.vertical)
                        
                        Text("Notification Sound")
                            .font(.headline)
                        
                        let soundKeys = ["boat-horn", "happy", "let-the-fun-begin", "short-beep", "ukulele", "system"]
                        
                        Menu {
                            ForEach(soundKeys, id: \.self) { key in
                                Button(action: {
                                    scheduleViewModel.selectedSound = key
                                    if key != "system" {
                                        playSound(key)
                                    }
                                }) {
                                    HStack {
                                        Text(scheduleViewModel.availableSounds[key] ?? "")
                                        if scheduleViewModel.selectedSound == key {
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
                                
                                Text(scheduleViewModel.availableSounds[scheduleViewModel.selectedSound] ?? "")
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
                    .padding(.bottom)
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
                                    "Smart notifications 5 minutes before waves",
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
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Settings")
    }
} 