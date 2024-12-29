import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: LakeStationsViewModel
    
    var body: some View {
        MapViewRepresentable(
            stations: viewModel.lakes.flatMap { lake in
                lake.stations.filter { $0.coordinates != nil }
            },
            onStationSelected: { station in
                viewModel.selectStation(station)
            }
        )
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let stations: [Lake.Station]
    let onStationSelected: (Lake.Station) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Initial region (Schweiz)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        )
        mapView.setRegion(region, animated: false)
        
        // Konfiguration
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Stationen hinzufügen
        let annotations = stations.compactMap { station -> StationAnnotation? in
            guard let coordinates = station.coordinates else { return nil }
            return StationAnnotation(
                station: station,
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
            )
        }
        mapView.addAnnotations(annotations)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update wenn sich Stationen ändern
        let currentAnnotations = mapView.annotations.compactMap { $0 as? StationAnnotation }
        let currentStationIds = Set(currentAnnotations.map { $0.station.id })
        let newStationIds = Set(stations.map { $0.id })
        
        if currentStationIds != newStationIds {
            mapView.removeAnnotations(mapView.annotations)
            let annotations = stations.compactMap { station -> StationAnnotation? in
                guard let coordinates = station.coordinates else { return nil }
                return StationAnnotation(
                    station: station,
                    coordinate: CLLocationCoordinate2D(
                        latitude: coordinates.latitude,
                        longitude: coordinates.longitude
                    )
                )
            }
            mapView.addAnnotations(annotations)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "Cluster"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.markerTintColor = .systemBlue
                return view
            }
            
            guard let annotation = annotation as? StationAnnotation else { return nil }
            
            let identifier = "StationMarker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            view.clusteringIdentifier = "stations"
            view.markerTintColor = .systemBlue
            view.glyphImage = UIImage(systemName: "mappin.circle.fill")
            view.canShowCallout = false
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                let region = MKCoordinateRegion(
                    center: cluster.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: mapView.region.span.latitudeDelta * 0.5,
                        longitudeDelta: mapView.region.span.longitudeDelta * 0.5
                    )
                )
                mapView.setRegion(region, animated: true)
            } else if let annotation = view.annotation as? StationAnnotation {
                parent.onStationSelected(annotation.station)
            }
            
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
    }
}

class StationAnnotation: NSObject, MKAnnotation {
    let station: Lake.Station
    let coordinate: CLLocationCoordinate2D
    
    var title: String? { station.name }
    
    init(station: Lake.Station, coordinate: CLLocationCoordinate2D) {
        self.station = station
        self.coordinate = coordinate
        super.init()
    }
} 