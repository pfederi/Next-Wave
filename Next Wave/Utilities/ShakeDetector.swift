//
//  ShakeDetector.swift
//  NextWave
//
//  Created by Patrick Federi
//

import SwiftUI
import CoreMotion

// Extension to detect device flip
extension UIDevice {
    static let deviceDidFlipNotification = Notification.Name(rawValue: "deviceDidFlipNotification")
}

// Motion Manager for device orientation detection
class DeviceMotionManager: ObservableObject {
    static let shared = DeviceMotionManager()
    
    private let motionManager = CMMotionManager()
    private var initialOrientation: Double?
    private var lastFlipTime = Date.distantPast
    private var hasTriggered = false
    
    private init() {}
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            // Get rotation around the z-axis (roll - phone rotating like a wheel)
            let roll = motion.attitude.roll
            
            // Initialize with first reading
            if self?.initialOrientation == nil {
                self?.initialOrientation = roll
                self?.hasTriggered = false
                return
            }
            
            guard let initialRoll = self?.initialOrientation else { return }
            
            // Calculate rotation difference from initial position
            var rotationDiff = abs(roll - initialRoll)
            
            // Normalize to 0-π range
            if rotationDiff > .pi {
                rotationDiff = 2 * .pi - rotationDiff
            }
            
            // Check if rotated approximately 180° (π radians)
            // Allow some tolerance: between 150° and 210° (2.6 to 3.7 radians)
            let isFlipped = rotationDiff > 2.6 && rotationDiff < 3.7
            
            if isFlipped && !(self?.hasTriggered ?? true) {
                let now = Date()
                if now.timeIntervalSince(self?.lastFlipTime ?? .distantPast) > 3.0 {
                    NotificationCenter.default.post(name: UIDevice.deviceDidFlipNotification, object: nil)
                    self?.lastFlipTime = now
                    self?.hasTriggered = true
                }
            } else if rotationDiff < 0.5 {
                // Zurück zur Ausgangsposition - reset für nächsten Flip
                self?.hasTriggered = false
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        initialOrientation = nil
    }
}

// ViewModifier to handle device flip
struct FlipViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                DeviceMotionManager.shared.startMonitoring()
            }
            .onDisappear {
                DeviceMotionManager.shared.stopMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidFlipNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onFlip(perform action: @escaping () -> Void) -> some View {
        self.modifier(FlipViewModifier(action: action))
    }
}

