import SwiftUI
import EventKit
import EventKitUI
import CoreLocation

/// Presents iOS's native event editor pre-filled from a `CalendarEventContent`.
/// No upfront permission prompt — EventKit requests write access only on save.
struct CalendarEventEditView: UIViewControllerRepresentable {
    let content: CalendarEventContent
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()

        let event = EKEvent(eventStore: store)
        event.title = content.title
        event.startDate = content.startDate
        event.endDate = content.endDate
        event.notes = content.notes

        if let name = content.locationName, !name.isEmpty {
            event.location = name
            if let lat = content.latitude, let lon = content.longitude {
                let structured = EKStructuredLocation(title: name)
                structured.geoLocation = CLLocation(latitude: lat, longitude: lon)
                event.structuredLocation = structured
            }
        }

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
            isPresented = false
        }
    }
}
