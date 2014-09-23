import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {

    var mapView: MKMapView!
    var image: UIImage?
    let maxAnnotationCount = 500

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        view.addSubview(mapView)

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
                if (annotations.count < self.maxAnnotationCount) {
                    annotations.addObject(annotation)
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                [unowned self] in
                if let mapView = self.mapView {
                    NSLog("adding %i annotations", annotations.count)
                    mapView.addAnnotations(annotations)
                    mapView.showAnnotations(mapView.annotations, animated: false)
                }
            }
        }
    }

    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (image == nil) {
            let diameter = 20
            UIGraphicsBeginImageContext(CGSize(width: diameter, height: diameter))
            let c = UIGraphicsGetCurrentContext()
            CGContextSetFillColorWithColor(c, UIColor.redColor().colorWithAlphaComponent(0.25).CGColor)
            CGContextSetStrokeColorWithColor(c, UIColor.redColor().CGColor)
            CGContextSetLineWidth(c, 1)
            CGContextAddEllipseInRect(c, CGRect(x: 0, y: 0, width: diameter, height: diameter))
            CGContextFillPath(c)
            CGContextStrokePath(c)
            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }

        let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        view.image = image

        return view
    }

}
