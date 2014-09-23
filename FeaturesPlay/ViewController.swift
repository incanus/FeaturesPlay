import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {

    var mapView: MKMapView!
    var redImage: UIImage!
    var blueImage: UIImage!
    var displayLink: CADisplayLink!
    var overlay: Overlay!

    let maxAnnotationCount = 100

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        view.addSubview(mapView)

        redImage = UIImage() //annotationImageWithColor(UIColor.redColor())
        blueImage = annotationImageWithColor(UIColor.blueColor())

        displayLink = CADisplayLink(target: self, selector: "updateOverlay:")
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)

        overlay = Overlay(frame: view.bounds, mapView: mapView)
        view.insertSubview(overlay, aboveSubview: mapView)

        mapView.addGestureRecognizer(UITapGestureRecognizer(target: overlay, action: "overlayTap:"))

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
        let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        view.image = redImage

        return view
    }

    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        overlay.setNeedsDisplay()
    }

    func updateOverlay(displayLink: CADisplayLink!) {
        overlay.setNeedsDisplay()
    }

    class Overlay: UIView {

        var mapView: MKMapView!
        var debugLabel: UILabel!
        var defaultImage: UIImage!
        var selectedImage: UIImage!
        var lastTap: CGPoint!

        init(frame: CGRect, mapView: MKMapView) {
            super.init(frame: frame)

            userInteractionEnabled = false

            backgroundColor = UIColor.clearColor()

            self.mapView = mapView

            debugLabel = UILabel(frame: CGRect(x: 10, y: 30, width: 200, height: 50))
            debugLabel.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.9)
            debugLabel.textAlignment = .Center
            debugLabel.numberOfLines = 0
            self.addSubview(debugLabel)

            defaultImage = annotationImageWithColor(UIColor.blueColor())
            selectedImage = annotationImageWithColor(UIColor.redColor())

            lastTap = CGPointZero
        }

        required init(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

        func overlayTap(gesture: UITapGestureRecognizer) {
            lastTap = gesture.locationInView(gesture.view)
        }

        override func drawRect(rect: CGRect) {
            let touchRect = CGRect(x: lastTap.x - 22, y: lastTap.y - 22, width: 44, height: 44)
            annotationImageWithColor(UIColor.blackColor().colorWithAlphaComponent(0.5), diameter: 30).drawInRect(touchRect)

            let tapCoordinate = mapView.convertPoint(lastTap, toCoordinateFromView: mapView)
            var closestAnnotation: MKPointAnnotation?
            for annotation in mapView.annotations {
                if let point = annotation as? MKPointAnnotation {
                    let p = mapView.convertCoordinate(point.coordinate, toPointToView: mapView)
                    if (CGRectContainsPoint(rect, p)) {
                        if (closestAnnotation == nil && lastTap != CGPointZero) {
                            closestAnnotation = point
                        } else if (closestAnnotation != nil) {
                            let tapLocation = CLLocation(latitude: tapCoordinate.latitude, longitude: tapCoordinate.longitude)
                            let oldDistance = tapLocation.distanceFromLocation(CLLocation(latitude: closestAnnotation!.coordinate.latitude, longitude: closestAnnotation!.coordinate.longitude))
                            let newDistance = tapLocation.distanceFromLocation(CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude))
                            if (newDistance < oldDistance) {
                                closestAnnotation = point
                            }
                        }
                    }
                }
            }

            var count = 0
            for annotation in mapView.annotations {
                if let point = annotation as? MKPointAnnotation {
                    let p = mapView.convertCoordinate(point.coordinate, toPointToView: mapView)
                    if (CGRectContainsPoint(rect, p)) {
                        var image: UIImage

                        if (point == closestAnnotation) {
                            image = selectedImage

                            let c = UIGraphicsGetCurrentContext()
                            CGContextSetStrokeColorWithColor(c, UIColor.blackColor().CGColor)
                            CGContextSetLineWidth(c, 3)

                            CGContextMoveToPoint(c, p.x, p.y)
                            CGContextAddLineToPoint(c, lastTap.x, lastTap.y)
                            CGContextStrokePath(c)
                        } else {
                            image = defaultImage
                        }

                        image.drawInRect(CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20))

                        count++
                    }
                }
            }

            debugLabel.text = "Total: \(mapView.annotations.count)\nRendered: \(count)"
        }

    }

}

func annotationImageWithColor(color: UIColor, diameter: Int = 20) -> UIImage {
    var image: UIImage

    UIGraphicsBeginImageContext(CGSize(width: diameter, height: diameter))
    let c = UIGraphicsGetCurrentContext()
    CGContextSetFillColorWithColor(c, color.colorWithAlphaComponent(0.5).CGColor)
    CGContextSetStrokeColorWithColor(c, color.CGColor)
    CGContextSetLineWidth(c, 1)
    CGContextAddEllipseInRect(c, CGRect(x: 0, y: 0, width: diameter, height: diameter))
    CGContextFillPath(c)
    CGContextStrokePath(c)
    image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return image
}
