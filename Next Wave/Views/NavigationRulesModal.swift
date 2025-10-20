//
//  NavigationRulesModal.swift
//  NextWave
//
//  Created by Patrick Federi on 12.12.2024.
//

import SwiftUI

struct NavigationRulesModal: View {
    @Binding var isPresented: Bool
    let isFirstLaunch: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    if isFirstLaunch {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Welcome to NextWave! 🌊")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color("text-color"))
                            
                            Text("Before you start catching waves, please read these important wakethieving rules for your safety and to preserve access to this amazing sport.")
                                .font(.body)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    // Distance Rules Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("Safe Distance Requirements")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        DistanceRuleCard()
                    }
                    .padding(.horizontal)
                    
                    // Ship Recognition Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("Identifying Priority Vessels")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        ShipIdentificationCard()
                    }
                    .padding(.horizontal)
                    
                    // Important Rules Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Critical Safety Rules")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        CriticalRulesCard()
                    }
                    .padding(.horizontal)
                    
                    // Safety Equipment Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Required Safety Equipment")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        SafetyEquipmentCard()
                    }
                    .padding(.horizontal)
                    
                    // Why This Matters Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Why This Matters")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        WhyItMattersCard()
                    }
                    .padding(.horizontal)
                    
                    // Code of Conduct Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.pink)
                                .font(.title2)
                            Text("Join Our Community")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("text-color"))
                        }
                        .padding(.top, 16)
                        
                        CommunityGuidelinesCard()
                    }
                    .padding(.horizontal)
                    
                    // Bottom message
                    HStack {
                        Spacer()
                        Text("Enjoy your waves responsibly! 🏄‍♂️")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("text-color"))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Wakethieving Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                        
                        // Mark first launch as completed
                        if isFirstLaunch {
                            UserDefaults.standard.set(true, forKey: "hasShownNavigationRules")
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Component Cards

struct DistanceRuleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "50.circle.fill")
                    .foregroundColor(.red)
                    .font(.title)
                Text("50 meters on each side")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("text-color"))
            }
            
            Text("Maintain at least 50 meters distance from priority vessels (passenger ships) on both sides.")
                .font(.body)
                .foregroundColor(Color("text-color"))
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("50 meters ≈ one boat length for most ships.")
                    .font(.callout)
                    .italic()
                    .foregroundColor(Color("text-color"))
            }
        }
        .padding()
        .background(Color("background-color").opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ShipIdentificationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority vessels are marked with:")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(Color("text-color"))
            
            VStack(alignment: .leading, spacing: 8) {
                IdentificationItem(
                    icon: "sun.max.fill",
                    color: .yellow,
                    title: "During daytime:",
                    description: "Green ball at the highest point."
                )
                
                IdentificationItem(
                    icon: "moon.stars.fill",
                    color: .blue,
                    title: "At night:",
                    description: "White light at bow (front), green light on starboard (right), red light on port (left), and green light at highest point."
                )
            }
        }
        .padding()
        .background(Color("background-color").opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CriticalRulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CriticalRuleItem(
                icon: "xmark.circle.fill",
                color: .red,
                title: "NEVER ride in front of the ship",
                description: "Always stay behind or to the side."
            )
            
            CriticalRuleItem(
                icon: "arrow.down.circle.fill",
                color: .orange,
                title: "Best waves are further back anyway",
                description: "You'll get better waves staying behind."
            )
            
            CriticalRuleItem(
                icon: "arrowshape.right.fill",
                color: .blue,
                title: "Leave the priority route as quickly as possible",
                description: "Don't linger in shipping lanes. Shipping lanes are visible on the map."
            )
        }
        .padding()
        .background(Color("background-color").opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SafetyEquipmentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SafetyEquipmentItem(
                icon: "circle.fill",
                color: .orange,
                title: "Highly visible head protection",
                description: "Wear bright, easily visible headgear for safety."
            )
            
            SafetyEquipmentItem(
                icon: "figure.water.fitness",
                color: .blue,
                title: "Life jacket required outside shore zone (300m)",
                description: "Minimum 50N buoyancy required when leaving 300m shore zone."
            )
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.green)
                Text("Restube offers inflatable life jackets perfect for this requirement.")
                    .font(.callout)
                    .italic()
                    .foregroundColor(Color("text-color"))
            }
        }
        .padding()
        .background(Color("background-color").opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WhyItMattersCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In an emergency stop, the captain must put the ship in reverse. This creates a powerful suction from the propeller that can be extremely dangerous.")
                .font(.body)
                .foregroundColor(Color("text-color"))
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Following these rules prevents accidents and keeps wakethieving legal!")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color("background-color").opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CommunityGuidelinesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Be part of the responsible pumpfoiling movement in Switzerland")
                .font(.body)
                .foregroundColor(Color("text-color"))
                .multilineTextAlignment(.leading)
            
            Link(destination: URL(string: "https://responsible.pumpfoiling.community/")!) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swiss Pumpfoilers Code of Conduct")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Join the community commitment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("background-color").opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
                .shadow(color: .blue.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color("background-color").opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Helper Views

struct IdentificationItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color("text-color"))
                
                Text(description)
                    .font(.callout)
                    .foregroundColor(Color("text-color"))
            }
        }
    }
}

struct CriticalRuleItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("text-color"))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color("text-color").opacity(0.7))
            }
        }
    }
}

struct SafetyEquipmentItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("text-color"))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color("text-color").opacity(0.7))
            }
        }
    }
}

#Preview {
    NavigationRulesModal(isPresented: .constant(true), isFirstLaunch: true)
}
