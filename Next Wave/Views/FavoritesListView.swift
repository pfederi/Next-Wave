import SwiftUI

struct FavoritesListView: View {
    @ObservedObject private var favoritesManager = FavoriteStationsManager.shared
    @ObservedObject var viewModel: LakeStationsViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Favorite Stations")
                    .font(.headline)
                    .foregroundColor(Color("text-color"))
                
                Spacer()
                
                if favoritesManager.favorites.count >= 2 {
                    Button(action: {
                        withAnimation {
                            editMode = editMode == .inactive ? .active : .inactive
                        }
                    }) {
                        Text(editMode == .active ? "Done" : "Edit")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 32)
            
            if editMode == .active {
                EditableFavoritesListView(
                    favorites: favoritesManager.favorites,
                    onMove: favoritesManager.reorderFavorites
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(favoritesManager.favorites) { favorite in
                        FavoriteStationTileView(
                            station: favorite,
                            onTap: {
                                print("🔵 [FavoritesListView] Tapped on favorite: \(favorite.name) with ID: \(favorite.id)")
                                viewModel.selectStation(withId: favorite.id)
                            },
                            viewModel: viewModel
                        )
                        .environmentObject(appSettings)
                        .padding(.horizontal)
                        .onLongPressGesture {
                            withAnimation {
                                editMode = .active
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EditableFavoritesListView: View {
    let favorites: [FavoriteStation]
    let onMove: (IndexSet, Int) -> Void
    @State private var editMode: EditMode = .active
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { favorite in
                    HStack {
                        Text(favorite.name)
                            .foregroundColor(Color("text-color"))
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .onMove(perform: onMove)
                .listRowBackground(Color("background-color"))
            }
            .listStyle(PlainListStyle())
            .environment(\.editMode, $editMode)
            .tint(Color("text-color"))
        }
        .frame(height: CGFloat(favorites.count * 60))
    }
} 