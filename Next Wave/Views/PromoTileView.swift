import SwiftUI

struct PromoTileView: View {
    let tile: PromoTile
    let onDismiss: () -> Void
    @State private var image: UIImage?
    @State private var isLoadingImage = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isDismissed = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Roter Delete-Button als Pille (hinter der Tile)
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = -500
                        isDismissed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }) {
                    Label("Dismiss", systemImage: "trash.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 16)
            }
            
            // Tile Content
            VStack(alignment: .leading, spacing: 12) {
                // Titel (erste Zeile) mit Promo-Chip
                HStack {
                    Text(tile.title)
                        .font(.headline)
                        .foregroundColor(Color("text-color"))
                    
                    Spacer()
                    
                    Text("Promo")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                
                // Bild links, Text + Link rechts
                HStack(alignment: .top, spacing: 12) {
                    // Bild (nur wenn vorhanden)
                    if let imageUrl = tile.imageUrl, !imageUrl.isEmpty {
                        ZStack {
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if isLoadingImage {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .task {
                            await loadImage(from: imageUrl)
                        }
                    }
                    
                    // Text + Link
                    VStack(alignment: .leading, spacing: 6) {
                        if let subtitle = tile.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(tile.text)
                            .font(.subheadline)
                            .foregroundColor(Color("text-color"))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Link direkt nach dem Text
                        if let linkUrl = tile.linkUrl, let url = URL(string: linkUrl) {
                            Button(action: {
                                UIApplication.shared.open(url)
                            }) {
                                Text(linkUrl)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .lineLimit(1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width < 0 {
                            // Nur nach links swipen erlauben, mit Widerstand
                            let translation = gesture.translation.width
                            offset = translation
                            isSwiping = true
                        }
                    }
                    .onEnded { gesture in
                        isSwiping = false
                        if gesture.translation.width < -80 {
                            // Dismiss wenn mehr als 80px geswiped
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = -500
                                isDismissed = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss()
                            }
                        } else {
                            // Zurück schnappen
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDismissed ? 0 : 1)
        .frame(height: isDismissed ? 0 : nil)
    }
    
    private func loadImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        isLoadingImage = true
        defer { isLoadingImage = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = uiImage
                }
            }
        } catch {
            // Image loading failed, silently ignore
        }
    }
}

#Preview {
    PromoTileView(
        tile: PromoTile(
            id: "1",
            title: "Neue Features",
            subtitle: "Version 2.0",
            text: "Entdecke die neuen Funktionen in der NextWave App! Jetzt mit verbesserter Performance und neuen Features.",
            imageUrl: nil,
            linkUrl: "https://nextwaveapp.ch",
            isActive: true,
            priority: 1,
            validFrom: nil,
            validUntil: nil
        ),
        onDismiss: {
            print("Tile dismissed")
        }
    )
    .padding()
}
