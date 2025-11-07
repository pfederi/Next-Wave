//
//  Next_WaveUITestsLaunchTests.swift
//  Next WaveUITests
//
//  Created by Patrick Federi on 12.12.2024.
//

import XCTest

final class Next_WaveUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        
        // Force portrait orientation
        XCUIDevice.shared.orientation = .portrait
        
        app.launch()

        // Dismiss any system alerts that might appear
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        
        // Wait a moment for alerts to appear
        sleep(2)
        
        // Accept location permission alert to enable Nearest Station
        // Try English buttons first
        if springboard.buttons["Allow While Using App"].exists {
            springboard.buttons["Allow While Using App"].tap()
        } else if springboard.buttons["Allow Once"].exists {
            springboard.buttons["Allow Once"].tap()
        }
        // Try German buttons
        else if springboard.buttons["Beim Verwenden der App erlauben"].exists {
            springboard.buttons["Beim Verwenden der App erlauben"].tap()
        } else if springboard.buttons["Einmal erlauben"].exists {
            springboard.buttons["Einmal erlauben"].tap()
        }
        
        sleep(2)
        
        // Dismiss notification permission alert (not needed for screenshot)
        if springboard.buttons["Don't Allow"].exists {
            springboard.buttons["Don't Allow"].tap()
        } else if springboard.buttons["Allow"].exists {
            springboard.buttons["Allow"].tap()
        }
        // Try German buttons
        else if springboard.buttons["Nicht erlauben"].exists {
            springboard.buttons["Nicht erlauben"].tap()
        } else if springboard.buttons["Erlauben"].exists {
            springboard.buttons["Erlauben"].tap()
        }
        
        sleep(2)
        
        // Dismiss any modal (Rules modal) by tapping outside or close button
        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
            sleep(1)
        } else if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
            sleep(1)
        } else if app.buttons["Dismiss"].exists {
            app.buttons["Dismiss"].tap()
            sleep(1)
        }
        
        // Wait longer for the app to fully load and calculate Nearest Station
        // This gives the location service time to determine the nearest station
        sleep(8)
        
        // Ensure we're in portrait mode
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        
        // Screenshot 1: Main departure view with Nearest Station visible
        snapshot("01-MainView")
        
        // Add first favorite: Küsnacht ZH (See)
        // Click on "Select Station" button
        if app.buttons["Select Station"].exists {
            app.buttons["Select Station"].tap()
        } else if app.buttons["Station auswählen"].exists {
            app.buttons["Station auswählen"].tap()
        }
        sleep(2)
        
        // Select Zürichsee
        if app.buttons["Zürichsee"].exists {
            app.buttons["Zürichsee"].tap()
        }
        sleep(2)
        
        // Select Küsnacht ZH (See)
        if app.buttons["Küsnacht ZH (See)"].exists {
            app.buttons["Küsnacht ZH (See)"].tap()
        }
        sleep(2)
        
        // Click heart icon to add as favorite
        if app.buttons["favorite"].exists {
            app.buttons["favorite"].tap()
        } else if app.navigationBars.buttons.element(boundBy: 1).exists {
            app.navigationBars.buttons.element(boundBy: 1).tap()
        }
        sleep(1)
        
        // Go back to main view
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        } else if app.buttons["Zurück"].exists {
            app.buttons["Zurück"].tap()
        }
        sleep(2)
        
        // Add second favorite: Thalwil (See)
        // Click on "Select Station" button again
        if app.buttons["Select Station"].exists {
            app.buttons["Select Station"].tap()
        } else if app.buttons["Station auswählen"].exists {
            app.buttons["Station auswählen"].tap()
        }
        sleep(2)
        
        // Zürichsee should already be expanded from before
        // If not, expand it
        if !app.buttons["Thalwil (See)"].exists && !app.buttons["Küsnacht ZH (See)"].exists {
            if app.buttons["Zürichsee"].exists {
                app.buttons["Zürichsee"].tap()
                sleep(2)
            }
        }
        
        // Scroll down to find Thalwil (See)
        var attempts = 0
        while !app.buttons["Thalwil (See)"].exists && attempts < 5 {
            app.swipeUp()
            sleep(1)
            attempts += 1
        }
        
        // Select Thalwil (See)
        if app.buttons["Thalwil (See)"].exists {
            app.buttons["Thalwil (See)"].tap()
        }
        sleep(2)
        
        // Click heart icon to add as favorite
        if app.buttons["favorite"].exists {
            app.buttons["favorite"].tap()
        } else if app.navigationBars.buttons.element(boundBy: 1).exists {
            app.navigationBars.buttons.element(boundBy: 1).tap()
        }
        sleep(1)
        
        // Go back to main view
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        } else if app.buttons["Zurück"].exists {
            app.buttons["Zurück"].tap()
        }
        sleep(2)
        
        // Add third favorite: Hilterfingen (See) from Thunersee
        // Click on "Select Station" button again
        if app.buttons["Select Station"].exists {
            app.buttons["Select Station"].tap()
        } else if app.buttons["Station auswählen"].exists {
            app.buttons["Station auswählen"].tap()
        }
        sleep(2)
        
        // Close Zürichsee first (it's still expanded)
        if app.buttons["Zürichsee"].exists {
            app.buttons["Zürichsee"].tap()
            sleep(1)
        }
        
        // Now open Thunersee
        if app.buttons["Thunersee"].exists {
            app.buttons["Thunersee"].tap()
            sleep(2)
        }
        
        // Scroll to find Hilterfingen (See)
        var attempts2 = 0
        while !app.buttons["Hilterfingen (See)"].exists && attempts2 < 5 {
            app.swipeUp()
            sleep(1)
            attempts2 += 1
        }
        
        // Select Hilterfingen (See)
        if app.buttons["Hilterfingen (See)"].exists {
            app.buttons["Hilterfingen (See)"].tap()
        }
        sleep(2)
        
        // Click heart icon to add as favorite
        if app.buttons["favorite"].exists {
            app.buttons["favorite"].tap()
        } else if app.navigationBars.buttons.element(boundBy: 1).exists {
            app.navigationBars.buttons.element(boundBy: 1).tap()
        }
        sleep(1)
        
        // Go back to main view
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        } else if app.buttons["Zurück"].exists {
            app.buttons["Zurück"].tap()
        }
        sleep(2)
        
        // Wait for all favorites to load on main view
        sleep(2)
    }
}
