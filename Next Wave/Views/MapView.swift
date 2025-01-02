import SwiftUI
import MapKit

class OpenStreetMapOverlay: MKTileOverlay {
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        
        // Cache-Verzeichnis erstellen
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        cacheDirectory = URL(fileURLWithPath: cachePath).appendingPathComponent("OSMTileCache")
        
        super.init(urlTemplate: template)
        self.canReplaceMapContent = true
        
        // Memory Cache konfigurieren
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Cache-Verzeichnis erstellen falls nötig
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    override func loadTile(at path: MKTileOverlayPath,
                         result: @escaping (Data?, Error?) -> Void) {
        let cacheKey = "\(path.x),\(path.y),\(path.z)" as NSString
        let filePath = cacheDirectory.appendingPathComponent(cacheKey as String)
        
        // 1. Prüfe Memory Cache
        if let cachedData = memoryCache.object(forKey: cacheKey) {
            result(cachedData as Data, nil)
            return
        }
        
        // 2. Prüfe Disk Cache
        if let diskData = try? Data(contentsOf: filePath) {
            memoryCache.setObject(diskData as NSData, forKey: cacheKey)
            result(diskData, nil)
            return
        }
        
        // 3. Lade von Netzwerk
        super.loadTile(at: path) { [weak self] data, error in
            guard let self = self, let tileData = data else {
                result(data, error)
                return
            }
            
            // In Memory Cache speichern
            self.memoryCache.setObject(tileData as NSData, forKey: cacheKey)
            
            // Auf Festplatte speichern
            try? tileData.write(to: filePath)
            
            result(tileData, error)
        }
    }
}

class ShippingRoutesOverlay: MKTileOverlay {
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let template = "https://tiles.openseamap.org/routes/{z}/{x}/{y}.png"
        
        // Cache-Verzeichnis erstellen
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        cacheDirectory = URL(fileURLWithPath: cachePath).appendingPathComponent("SeaRouteTileCache")
        
        super.init(urlTemplate: template)
        self.canReplaceMapContent = false
        
        // Memory Cache konfigurieren
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Cache-Verzeichnis erstellen falls nötig
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    override func loadTile(at path: MKTileOverlayPath,
                         result: @escaping (Data?, Error?) -> Void) {
        let cacheKey = "\(path.x),\(path.y),\(path.z)" as NSString
        let filePath = cacheDirectory.appendingPathComponent(cacheKey as String)
        
        // 1. Prüfe Memory Cache
        if let cachedData = memoryCache.object(forKey: cacheKey) {
            result(cachedData as Data, nil)
            return
        }
        
        // 2. Prüfe Disk Cache
        if let diskData = try? Data(contentsOf: filePath) {
            memoryCache.setObject(diskData as NSData, forKey: cacheKey)
            result(diskData, nil)
            return
        }
        
        // 3. Lade von Netzwerk
        super.loadTile(at: path) { [weak self] data, error in
            guard let self = self, let tileData = data else {
                result(data, error)
                return
            }
            
            // In Memory Cache speichern
            self.memoryCache.setObject(tileData as NSData, forKey: cacheKey)
            
            // Auf Festplatte speichern
            try? tileData.write(to: filePath)
            
            result(tileData, error)
        }
    }
}

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

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let stations: [Lake.Station]
    let initialRegion: MKCoordinateRegion
    let onRegionChanged: (MKCoordinateRegion) -> Void
    let onStationSelected: (Lake.Station) -> Void
    @StateObject private var locationManager = LocationManager()
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(initialRegion, animated: false)
        
        // Force Light Mode
        mapView.overrideUserInterfaceStyle = .light
        
        // Zoom-Beschränkungen setzen (OSM unterstützt Levels 0-19)
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 500,  // Maximaler Zoom (weiter weg = weniger Zoom)
            maxCenterCoordinateDistance: 1_000_000  // Minimaler Zoom
        )
        
        // Start mit Apple Maps
        mapView.mapType = .standard
        
        // OSM und Schifffahrtswege Layer vorbereiten
        let osmOverlay = OpenStreetMapOverlay()
        let routesOverlay = ShippingRoutesOverlay()
        
        // Layer initial unsichtbar machen
        context.coordinator.osmRenderer = MKTileOverlayRenderer(overlay: osmOverlay)
        context.coordinator.osmRenderer?.alpha = 0
        context.coordinator.routesRenderer = MKTileOverlayRenderer(overlay: routesOverlay)
        context.coordinator.routesRenderer?.alpha = 0
        
        mapView.addOverlay(osmOverlay, level: .aboveLabels)
        mapView.addOverlay(routesOverlay, level: .aboveLabels)
        
        // Benutzerposition anzeigen
        mapView.showsUserLocation = true
        
        // Location Manager starten
        locationManager.requestLocationPermission()
        locationManager.startUpdatingLocation()
        
        // Konfiguration
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Locate Me Button hinzufügen
        let locateButton = MKUserTrackingButton(mapView: mapView)
        locateButton.layer.backgroundColor = UIColor.systemBackground.cgColor
        locateButton.layer.cornerRadius = 5
        locateButton.layer.borderWidth = 1
        locateButton.layer.borderColor = UIColor.separator.cgColor
        mapView.addSubview(locateButton)
        locateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            locateButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            locateButton.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
        
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
        var osmRenderer: MKTileOverlayRenderer?
        var routesRenderer: MKTileOverlayRenderer?
        private var isFirstTileLoaded = false
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "Cluster"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.markerTintColor = .systemBlue
                view.titleVisibility = .visible
                view.subtitleVisibility = .hidden
                view.displayPriority = .required
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
            view.titleVisibility = .visible
            view.subtitleVisibility = .hidden
            view.displayPriority = .required
            
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
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let topController = window.rootViewController?.topMostViewController() {
                    topController.dismiss(animated: true)
                }
            }
            
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChanged(mapView.region)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? OpenStreetMapOverlay {
                return osmRenderer ?? MKTileOverlayRenderer(overlay: tileOverlay)
            } else if let tileOverlay = overlay as? ShippingRoutesOverlay {
                return routesRenderer ?? MKTileOverlayRenderer(overlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
            guard !isFirstTileLoaded else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIView.animate(withDuration: 0.3) {
                    self.osmRenderer?.alpha = 1.0
                    self.routesRenderer?.alpha = 1.0
                    mapView.mapType = .mutedStandard
                }
                self.isFirstTileLoaded = true
            }
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let maxZoom: CLLocationDistance = 500
            let minZoom: CLLocationDistance = 1_000_000
            
            if mapView.camera.centerCoordinateDistance < maxZoom {
                mapView.camera.centerCoordinateDistance = maxZoom
            } else if mapView.camera.centerCoordinateDistance > minZoom {
                mapView.camera.centerCoordinateDistance = minZoom
            }
        }
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
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