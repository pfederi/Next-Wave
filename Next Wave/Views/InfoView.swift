import SwiftUI

struct InfoView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Catch the perfect wave behind scheduled passenger ships on Swiss lakes.")
                        .font(.body)
                    
                    Text("Safety First 🚨")
                        .font(.title2)
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
                    
                    Text("How it works 🎯")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1.") + Text(" Select your spot")
                        Text("2.") + Text(" Check the timetable")
                        Text("3.") + Text(" Set notifications with a swipe from right to left")
                        Text("4.") + Text(" Enjoy your ride!")
                    }
                    .font(.body)
                    
                    Text("Features 🌊")
                        .font(.title2)
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
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Info")
    }
} 