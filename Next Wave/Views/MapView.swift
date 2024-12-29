import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: LakeStationsViewModel
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        MapViewRepresentable(
            stations: viewModel.lakes.flatMap { lake in
                lake.stations.filter { $0.coordinates != nil }
            },
            initialRegion: MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: settings.lastMapRegion.latitude,
                    longitude: settings.lastMapRegion.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: settings.lastMapRegion.latitudeDelta,
                    longitudeDelta: settings.lastMapRegion.longitudeDelta
                )
            ),
            onRegionChanged: { region in
                settings.lastMapRegion = MapRegion(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude,
                    latitudeDelta: region.span.latitudeDelta,
                    longitudeDelta: region.span.longitudeDelta
                )
            },
            onStationSelected: { station in
                viewModel.selectStation(station)
            }
        )
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let stations: [Lake.Station]
    let initialRegion: MKCoordinateRegion
    let onRegionChanged: (MKCoordinateRegion) -> Void
    let onStationSelected: (Lake.Station) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(initialRegion, animated: false)
        
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
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChanged(mapView.region)
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