import UIKit
import MapKit

class ViewController: UIViewController {

    var mapView: MKMapView?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = MKMapView(frame: view.bounds)
        view.addSubview(mapView!)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            [unowned self] in
            let jsonData = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("fire-hydrants", ofType: "geojson")!)
            let jsonObject = NSJSONSerialization.JSONObjectWithData(jsonData, options: nil, error: nil) as NSDictionary
            let hydrants = jsonObject["features"] as NSArray
            var annotations = NSMutableArray()
            for hydrant in hydrants {
                let properties = hydrant["properties"] as NSDictionary
                let annotation = MKPointAnnotation()
                annotation.title = properties["NAME"] as NSString
                annotation.subtitle = {
                    let description = properties["DESCRIPTIO"] as NSString
                    let parts = description.componentsSeparatedByString("<p")
                    return parts[0] as NSString
                }()
                annotation.coordinate = {
                    let geometry = hydrant["geometry"] as NSDictionary
                    let coordinates = geometry["coordinates"] as NSArray
                    return CLLocationCoordinate2DMake(coordinates[1] as Double, coordinates[0] as Double)
                }()
                annotations.addObject(annotation)
            }
            dispatch_async(dispatch_get_main_queue()) {
                [unowned self] in
                if let mapView = self.mapView {
                    mapView.addAnnotations(annotations)
                    mapView.showAnnotations(mapView.annotations, animated: false)
                }
            }
        }
    }

}
