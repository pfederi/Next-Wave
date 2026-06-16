import SwiftUI

/// Compact check-in indicator shown in a departure row.
/// Tapping opens a popover that lists who's going and lets you join/leave.
struct WaveCheckinBadge: View {
    let count: Int
    let names: [String]
    let isMine: Bool
    let onToggle: () -> Void

    @State private var showDetails = false

    var body: some View {
        Button(action: { showDetails = true }) {
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
        .popover(isPresented: $showDetails) {
            detailContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var detailContent: some View {
        let anonymous = max(0, count - names.count)
        return VStack(alignment: .leading, spacing: 10) {
            Text(count == 0 ? "No one yet — be the first!" : "\(count) riding this wave 🌊")
                .font(.headline)

            if !names.isEmpty || anonymous > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(names, id: \.self) { name in
                        Label(name, systemImage: "person.fill")
                            .font(.subheadline)
                    }
                    if anonymous > 0 {
                        Label("\(anonymous) anonymous", systemImage: "person.fill.questionmark")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider()

            Button(action: {
                showDetails = false
                onToggle()
            }) {
                Label(isMine ? "Maybe next wave" : "I'm in! 🤙",
                      systemImage: isMine ? "person.badge.minus" : "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isMine ? .red : .blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .frame(minWidth: 200, alignment: .leading)
    }
}
