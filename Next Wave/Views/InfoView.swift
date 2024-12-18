import SwiftUI

struct InfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Catch the perfect wave behind scheduled passenger ships on Swiss lakes.")
                        .font(.body)
                    
                    Text("Safety First 🚨")
                        .font(.title2)
                    Text("• Keep a safe distance from the ship\n• Don't ride directly behind the boat\n• Be respectful to other water users\n• Follow local regulations")
                        .font(.body)
                    
                    Text("How it works 🎯")
                        .font(.title2)
                    Text("1. Select your spot\n2. Check the timetable\n3. Set notifications with a swipe to the right\n4. Enjoy your ride!")
                        .font(.body)
                    
                    Text("Features 🌊")
                        .font(.title2)
                    Text("• Real-time boat schedule tracking\n• Smart notifications 5 minutes before waves\n• Easy spot selection on Swiss Lakes\n• Precise wave timing information\n• Custom boat horn notifications")
                        .font(.body)
                    
                }
                .foregroundColor(Color("text-color"))
                
                Spacer()

                Group {
                    Link("Privacy Policy", destination: URL(string: "https://pumpfoiling.community/next-wave-app-privacy-policy/")!)
                        .font(.body)
                        .foregroundColor(.accentColor)

                    Link("Visit pumpfoiling.community", destination: URL(string: "https://pumpfoiling.community")!)
                        .font(.body)
                        .foregroundColor(.accentColor)
                }
                .foregroundColor(Color("text-color"))

                Spacer()
                
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Info")
    }
} 