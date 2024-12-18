import SwiftUI

struct LoaderView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("Loading departures...")
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }
} 