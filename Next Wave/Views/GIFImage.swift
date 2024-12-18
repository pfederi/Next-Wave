import SwiftUI
import UIKit
import ImageIO

struct GIFImage: UIViewRepresentable {
    let name: String
    let onAnimationComplete: () -> Void
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        if let path = Bundle.main.path(forResource: name, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let source =  CGImageSourceCreateWithData(data as CFData, nil) {
            
            let frameCount = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var duration: TimeInterval = 0
            
            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    let image = UIImage(cgImage: cgImage)
                    images.append(image)
                    
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                            duration += delayTime
                        }
                    }
                }
            }
            
            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.animationRepeatCount = 1  // Play only once
            imageView.startAnimating()
            
            // Schedule completion callback
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                onAnimationComplete()
            }
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {}
} 