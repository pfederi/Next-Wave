import SwiftUI

struct StationButton: View {
    let stationName: String?
    @Binding var showPicker: Bool
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(Color("text-color"))
                    .font(.system(size: 20))
                    .padding(.trailing, 8)
                
                Text(stationName ?? "Select Station")
                    .foregroundColor(Color("text-color"))
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "chevron.right")
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
                    .stroke((Color("text-color")).opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
} 