import SwiftUI

struct FavoriteStationsEditView: View {
    @ObservedObject private var favoritesManager = FavoriteStationsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        List {
            if favoritesManager.favorites.count >= 2 {
                ForEach(favoritesManager.favorites) { favorite in
                    HStack {
                        Text(favorite.name)
                            .foregroundColor(Color("text-color"))
                        Spacer()
                        if editMode == .active {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onMove { from, to in
                    favoritesManager.reorderFavorites(fromOffsets: from, toOffset: to)
                }
            } else {
                Text("Add at least two favorite spots to enable reordering")
                    .foregroundColor(Color("text-color"))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .navigationTitle("Edit Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if favoritesManager.favorites.count >= 2 {
                    EditButton()
                }
            }
        }
        .environment(\.editMode, $editMode)
    }
}

#Preview {
    NavigationView {
        FavoriteStationsEditView()
    }
} 