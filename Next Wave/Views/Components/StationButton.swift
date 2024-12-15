import SwiftUI

struct StationButton: View {
    let stationName: String?
    @Binding var showPicker: Bool
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Text(stationName ?? "Select Station")
                    .foregroundColor(stationName == nil ? .gray : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
            .padding(.horizontal)
        }
    }
} 