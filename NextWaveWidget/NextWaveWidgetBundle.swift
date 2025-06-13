//
//  NextWaveWidgetBundle.swift
//  NextWaveWidget
//
//  Created by Patrick Federi on 12.06.2025.
//

import WidgetKit
import SwiftUI

@main
struct NextWaveWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Only iOS widgets in this bundle
        NextWaveiPhoneWidget()
        NextWaveiPhoneMultipleWidget()
    }
} 