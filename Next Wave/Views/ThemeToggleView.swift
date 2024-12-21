import SwiftUI

struct ThemeToggleView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.headline)
            
            Menu {
                Button(action: {
                    appSettings.theme = .system
                }) {
                    HStack {
                        Text("System")
                        if case .system = appSettings.theme {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    appSettings.theme = .light
                }) {
                    HStack {
                        Text("Light Mode")
                        if case .light = appSettings.theme {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button(action: {
                    appSettings.theme = .dark
                }) {
                    HStack {
                        Text("Dark Mode")
                        if case .dark = appSettings.theme {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: {
                        switch appSettings.theme {
                        case .light: return "sun.max.fill"
                        case .dark: return "moon.fill"
                        case .system: return "gearshape.fill"
                        }
                    }())
                    .foregroundColor(Color("text-color"))
                    .font(.system(size: 20))
                    .padding(.trailing, 8)
                    
                    Text({
                        switch appSettings.theme {
                        case .light: return "Light Mode"
                        case .dark: return "Dark Mode"
                        case .system: return "System"
                        }
                    }())
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
} 