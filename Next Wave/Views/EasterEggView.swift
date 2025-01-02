import SwiftUI

struct EasterEggView: View {
    @Binding var isShowing: Bool
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    let isOverlay: Bool
    
    init(isShowing: Binding<Bool>, isOverlay: Bool = false) {
        self._isShowing = isShowing
        self.isOverlay = isOverlay
    }
    
    private func handleTap() {
        let now = Date()
        
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) > 0.5 {
            tapCount = 0
        }
        
        tapCount += 1
        lastTapTime = now
        
        if tapCount == 5 {
            withAnimation {
                isShowing = true
            }
        }
    }
    
    var body: some View {
        if isOverlay {
            if isShowing {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.3)
                        
                        GIFImage(name: "jack_sparrow") {
                            withAnimation {
                                isShowing = false
                            }
                            tapCount = 0
                        }
                        .frame(width: 300, height: 300)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                    }
                }
                .ignoresSafeArea()
            }
        } else {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
        }
    }
}

struct RainDropModifier: ViewModifier {
    let startY: CGFloat
    let endY: CGFloat
    let delay: Double
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? endY - startY : 0)
            .onAppear {
                withAnimation(
                    Animation
                        .linear(duration: 2)
                        .delay(delay)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
} 