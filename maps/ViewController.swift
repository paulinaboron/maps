//
//  ViewController.swift
//  maps
//
//  Created by Paulina Boroń on 24/03/2023.
//

import UIKit
import MapKit
import AVFoundation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mkv: MKMapView!
    var manager: CLLocationManager = CLLocationManager()
    
    let speaker = AVSpeechSynthesizer()
    
    var currentLocation: CLLocation!
    var pins: [MapPin] = []
    var mapItems : [MKMapItem] = []
    
    let voice = AVSpeechSynthesisVoice(language: "pl-PL")
    let synthesizer = AVSpeechSynthesizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        mkv.delegate = self
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.requestAlwaysAuthorization()
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()   // stopUpdatingLocation()
        
        mkv.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.bank]) // including - widoczne/ukryte warstwy
        mkv.showsUserLocation = true
        mkv.userTrackingMode = .followWithHeading // .follow
        
        searchBar.delegate = self
        
        mkv.register(CustomAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
    
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //        print("location update")
        //        print(locations.first)
        currentLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("***************")
        print(region.description)
        print(region.identifier)
        
        let utterance = AVSpeechUtterance(string: region.description)
        self.synthesizer.speak(utterance)
        
        let utterance2 = AVSpeechUtterance(string: "region")
        self.synthesizer.speak(utterance2)
        
        manager.stopMonitoring(for: region)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        print("klik " + searchBar.text!)
        
        let lr = MKLocalSearch.Request()
        lr.naturalLanguageQuery = searchBar.text
        
        let region = MKCoordinateRegion(center: currentLocation.coordinate, span:MKCoordinateSpan(latitudeDelta: 2.1, longitudeDelta: 2.1))
        lr.region = region
        
        let lS = MKLocalSearch(request: lr)
        lS.start { (response, _) in
            
            if(response == nil){
                var dialogMessage = UIAlertController(title: "Nie znaleziono", message: "Wpisz coś innego", preferredStyle: .alert)
                
                // Create OK button with action handler
                let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                    print("Ok button tapped")
                 })
                
                //Add OK button to a dialog message
                dialogMessage.addAction(ok)
                // Present Alert to
                self.present(dialogMessage, animated: true, completion: nil)
                return
            }
            
            print(response!.mapItems[0])
            self.mapItems = response!.mapItems
            
            for p in self.pins{
                self.mkv.removeAnnotation(p)
            }
            
            
            for i in 0...((response?.mapItems.count)! - 1){
                let pin = MapPin(title: (response?.mapItems[i].name)!, locationName: (response?.mapItems[i].name)!, coordinate: (response?.mapItems[i].placemark.coordinate)!)
                self.pins.append(pin)
                self.mkv.addAnnotations([pin])
            }
            
            self.navigate(destination: (response?.mapItems.first)!)
        }
        
    }
    
    func navigate(destination: MKMapItem){
        for o in self.mkv.overlays{
            self.mkv.removeOverlay(o)
        }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.currentLocation.coordinate))
        
        request.destination = destination // z naszego wyszukania MKLocalSearch
        request.requestsAlternateRoutes = true
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate {  (response, _) in
            if (response!.routes.count > 0) {
                self.mkv.addOverlay(response!.routes[0].polyline)
                self.mkv.setVisibleMapRect(response!.routes[0].polyline.boundingMapRect, animated: true)
                
                print("??????????????????")
                print(response?.routes.first?.steps.first?.instructions)
                
                let utterance = AVSpeechUtterance(string: response?.routes.first?.steps.first!.instructions ?? "")
                self.synthesizer.speak(utterance)
                
                for step in response!.routes.first!.steps{
                    let region = CLCircularRegion(center: step.polyline.coordinate, radius: 10, identifier: "id")
                    self.manager.startMonitoring(for: region)
                    let circle = MKCircle(center: region.center, radius: region.radius) // regiony punkt nizej
                    self.mkv.addOverlay(circle)
                }
            }
        }
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline{
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = .blue
            polylineRenderer.lineWidth = 5
            return polylineRenderer
        }else{
            let renderer = MKCircleRenderer(overlay: overlay)
                renderer.lineWidth = 3
                renderer.strokeColor = .red
                return renderer

        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {

        let dialogMessage = UIAlertController(title: "Potwierdź", message: "Czy napewno chcesz zmienić trasę?", preferredStyle: .alert)
        // Create OK button with action handler
        let ok = UIAlertAction(title: "Tak", style: .default, handler: { (action) -> Void in
            if let annotation = view.annotation as? MapPin {
                
                let lat = (annotation.coordinate.latitude*100).rounded()/100
                let long = (annotation.coordinate.longitude*100).rounded()/100
                
                for item in self.mapItems {
                    var itemLatitude = (item.placemark.region as! CLCircularRegion).center.latitude;
                    itemLatitude = (itemLatitude*100).rounded()/100
                    
                    var itemLongtitude = (item.placemark.region as! CLCircularRegion).center.longitude;
                    itemLongtitude = (itemLongtitude*100).rounded()/100
                    
                    if itemLatitude == lat && itemLongtitude == long{
                        self.navigate(destination: item)
                        break;
                    }
                }
            }
        })
        // Create Cancel button with action handlder
        let cancel = UIAlertAction(title: "Nie", style: .cancel) { (action) -> Void in
            return;
        }
        //Add OK and Cancel button to an Alert object
        dialogMessage.addAction(ok)
        dialogMessage.addAction(cancel)
        // Present alert message to user
        self.present(dialogMessage, animated: true, completion: nil)
        
            
        }
}

class MapPin: NSObject, MKAnnotation {
    let title: String?
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    init(title: String, locationName: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.locationName = locationName
        self.coordinate = coordinate
    }
}

class CustomAnnotationView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        glyphImage = UIImage(named: "icon")   // icon z Assets
        markerTintColor = .black
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

