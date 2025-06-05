import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    private let sharedDataManager = SharedDataManager.shared
    
    // MARK: - Timeline Configuration
    
    func timelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
        handler(Date().addingTimeInterval(24 * 60 * 60)) // Support up to 24 hours in the future
    }
    
    func privacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show this complication on the lock screen
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Get the latest departure info
        let departures = sharedDataManager.loadNextDepartures()
        guard let firstDeparture = departures.first,
              let nextDeparture = FavoriteNextDeparture.from(firstDeparture) else {
            handler(nil)
            return
        }
        
        // Create the template based on the complication family
        var template: CLKComplicationTemplate?
        
        switch complication.family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: nextDeparture.stationName),
                body1TextProvider: CLKSimpleTextProvider(text: "→ \(nextDeparture.destination)"),
                body2TextProvider: CLKSimpleTextProvider(text: "in \(nextDeparture.minutesUntilDeparture) min")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .utilitarianSmall, .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)m")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(
                    text: "\(nextDeparture.stationName) → \(nextDeparture.destination) (\(nextDeparture.minutesUntilDeparture)m)"
                )
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText(
                line1TextProvider: CLKSimpleTextProvider(text: nextDeparture.stationName),
                line2TextProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)m")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)"),
                outerTextProvider: CLKSimpleTextProvider(text: "min")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            let template = CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: CLKSimpleTextProvider(text: "\(nextDeparture.stationName) → \(nextDeparture.destination)")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "\(nextDeparture.minutesUntilDeparture)"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: nextDeparture.stationName),
                body1TextProvider: CLKSimpleTextProvider(text: "→ \(nextDeparture.destination)"),
                body2TextProvider: CLKSimpleTextProvider(text: "in \(nextDeparture.minutesUntilDeparture) min")
            )
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
            
        @unknown default:
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after the given date
        handler(nil)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // Create a template with sample data
        let sampleDeparture = FavoriteNextDeparture(
            stationName: "Brienz",
            destination: "Interlaken",
            minutesUntilDeparture: 17
        )
        
        var template: CLKComplicationTemplate?
        
        switch complication.family {
        case .modularSmall:
            template = CLKComplicationTemplateModularSmallStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "17"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            
        case .modularLarge:
            template = CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: sampleDeparture.stationName),
                body1TextProvider: CLKSimpleTextProvider(text: "→ \(sampleDeparture.destination)"),
                body2TextProvider: CLKSimpleTextProvider(text: "in \(sampleDeparture.minutesUntilDeparture) min")
            )
            
        case .utilitarianSmall, .utilitarianSmallFlat:
            template = CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: "17m")
            )
            
        case .utilitarianLarge:
            template = CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(
                    text: "Brienz → Interlaken (17m)"
                )
            )
            
        case .circularSmall:
            template = CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "17")
            )
            
        case .extraLarge:
            template = CLKComplicationTemplateExtraLargeStackText(
                line1TextProvider: CLKSimpleTextProvider(text: sampleDeparture.stationName),
                line2TextProvider: CLKSimpleTextProvider(text: "17m")
            )
            
        case .graphicCorner:
            template = CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: "17"),
                outerTextProvider: CLKSimpleTextProvider(text: "min")
            )
            
        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "17"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            template = CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: CLKSimpleTextProvider(text: "Brienz → Interlaken")
            )
            
        case .graphicCircular:
            template = CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "17"),
                line2TextProvider: CLKSimpleTextProvider(text: "min")
            )
            
        case .graphicRectangular:
            template = CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: sampleDeparture.stationName),
                body1TextProvider: CLKSimpleTextProvider(text: "→ \(sampleDeparture.destination)"),
                body2TextProvider: CLKSimpleTextProvider(text: "in \(sampleDeparture.minutesUntilDeparture) min")
            )
            
        @unknown default:
            break
        }
        
        handler(template)
    }
} 