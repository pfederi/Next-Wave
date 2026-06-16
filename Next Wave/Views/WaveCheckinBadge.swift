import SwiftUI

/// Compact, tappable check-in indicator shown in a departure row.
/// Tap toggles the user's own check-in; long-press reveals the names.
struct WaveCheckinBadge: View {
    let count: Int
    let names: [String]
    let isMine: Bool
    let onTap: () -> Void

    @State private var showNames = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: isMine ? "person.2.fill" : "person.2")
                if count > 0 {
                    Text("\(count)")
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isMine ? .blue : (count > 0 ? .primary : .gray))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            if count > 0 { showNames = true }
        }
        .popover(isPresented: $showNames) {
            let anonymous = max(0, count - names.count)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                }
                if anonymous > 0 {
                    Text("+\(anonymous) anonymous")
                        .foregroundColor(.gray)
                }
                if names.isEmpty && anonymous == 0 {
                    Text("No one yet")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}
