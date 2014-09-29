import MapKit
import XCPlayground

public struct PMapPoint {
    public var x: Double
    public var y: Double
}

public struct PMapSize {
    public var width: Double
    public var height: Double
}

public struct PMapRect {
    public var origin: PMapPoint
    public var size: PMapSize
}

public struct Utilities {

    static let R: Double = 6_378_137

    static let scaleDenominators: Array<Double> = {
        var values = Array<Double>()
        for zoom in 0...20 {
            let scale = pow(0.5, Double(zoom))
            let denominator = 1 / scale
            values.append(denominator)
        }
        return values
    }()

    public static func zoomForScale(scale: Double) -> Double {
        let denominator = 1 / scale
        for (zoom, lowerScaleDenominator) in enumerate(scaleDenominators) {
            let higherScaleDenominator = lowerScaleDenominator * 2
            if (denominator >= lowerScaleDenominator && denominator <= higherScaleDenominator) {
                let ratio = (denominator - lowerScaleDenominator) / lowerScaleDenominator
                return Double(zoom) + ratio
            }
        }
        return 0
    }

    public static func scaleForZoom(zoom: Double) -> Double {
        return 1 / pow(2, zoom)
    }

    public static func pixelWidthAtZoom(zoom: Double) -> Double {
        return pow(2, zoom) * 256
    }

    public static let BoundsInMeters: PMapRect = {
        let d: Double = R * M_PI

        return PMapRect(origin: PMapPoint(x: -d, y: -d), size: PMapSize(width: d * 2, height: d * 2))
    }()

    public static let SizeInMeters: PMapSize = {
        return PMapSize(width: BoundsInMeters.size.width,
            height: BoundsInMeters.size.height)
    }()

    public static func metersPerPixelAtLatitude(lat: CLLocationDegrees, zoom: Double) -> Double {
        var adjustedLat = max(min(lat, 85), -85)

        return cos(adjustedLat * M_PI / 180) * 2 * M_PI * R / pixelWidthAtZoom(zoom)
    }

    public static func projectedMetersFromCoordinate(coordinate: CLLocationCoordinate2D) -> PMapPoint {
        let lon = coordinate.longitude
        let lat = max(min(coordinate.latitude, 85), -85)

        let d: Double = M_PI / 180
        let m: Double = 1 - Double(1e-15)
        let s: Double = max(min(sin(lat * d), m), -m)

        let px = R * lon * d
        let py = R * log((1 + s) / (1 - s)) / 2

        return PMapPoint(x: px, y: py)
    }

    public static func coordinateFromProjectedMeters(point: PMapPoint) -> CLLocationCoordinate2D {
        let d: Double = 180 / M_PI

        var lat = (2 * atan(exp(point.y / R)) - (M_PI / 2)) * d
        let lon = Double(point.x) * d / R

        lat = max(min(lat, 85), -85)

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public static func mapPointForCoordinate(coordinate: CLLocationCoordinate2D) -> PMapPoint {
        let metersPerPixel = metersPerPixelAtLatitude(coordinate.latitude, zoom: 20)

        let projectedMeters = projectedMetersFromCoordinate(coordinate)
        let shiftedOriginMeters = PMapPoint(x: projectedMeters.x + SizeInMeters.width / 2, y: projectedMeters.y - SizeInMeters.height / 2)

        let width = pixelWidthAtZoom(20)

        let px = abs(shiftedOriginMeters.x * (width / SizeInMeters.width))
        let py = abs(shiftedOriginMeters.y * (width / SizeInMeters.height))

        return PMapPoint(x: px, y: py)
    }

    public static func coordinateForMapPoint(point: PMapPoint) -> CLLocationCoordinate2D {
        let width = pixelWidthAtZoom(20)

        let shiftedOriginMeters = PMapPoint(x: point.x / (width / SizeInMeters.width), y: point.y / (width / SizeInMeters.height))

        let projectedMeters = PMapPoint(x: shiftedOriginMeters.x - SizeInMeters.width / 2, y: SizeInMeters.height / 2 - shiftedOriginMeters.y)

        let coordinate = coordinateFromProjectedMeters(projectedMeters)

        return coordinate
    }

    public enum DistanceMethod {
        case SphericalCosine
        case Haversine
        case Apple
    }

    public static func metersBetweenMapPoints(a: PMapPoint, b: PMapPoint, method: DistanceMethod = .Apple) -> CLLocationDistance {
        let c1 = coordinateForMapPoint(a)
        let c2 = coordinateForMapPoint(b)

        switch (method) {
        case .SphericalCosine:
            let rad = M_PI / 180
            let lat1 = c1.latitude * rad
            let lat2 = c2.latitude * rad
            let a = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos((c2.longitude - c1.longitude) * rad)

            let d = R * acos(min(a, 1))

            return d
        case .Haversine:
            let rad = M_PI / 180
            let dlat = (c2.latitude - c1.latitude) * rad
            let dlon = (c2.longitude - c1.longitude) * rad
            let a1 = sin(dlat / 2) * sin(dlat / 2)
            let a2 = sin(dlon / 2) * sin(dlon / 2)
            let a3 = cos(c1.latitude * rad)
            let a4 = cos(c2.latitude * rad)
            let a = a1 + a2 * a3 * a4
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))

            let d = R * c
            
            return d
        case .Apple:
            return CLLocation(latitude: c1.latitude, longitude: c1.longitude).distanceFromLocation(CLLocation(latitude: c2.latitude, longitude: c2.longitude))
        }
    }
    
}

func ll(lat: CLLocationDegrees, lon: CLLocationDegrees) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}

typealias Projection = Utilities

println("Example Coordinate")
let c = ll(38.902524, -76.999338)

println("Equivalent Apple MKMapPoint ([90, -180] origin)")
let appP = MKMapPointForCoordinate(c)

println("Apple world layout")
let appSize = MKMapSizeWorld
let appMetersPerPointEquator = MKMetersPerMapPointAtLatitude(0)
let appMetersPerPointPole = MKMetersPerMapPointAtLatitude(90)
let appMetersWidthEquator = MKMapSizeWorld.width * appMetersPerPointEquator
let appMetersWidthPole = MKMapSizeWorld.width * appMetersPerPointPole
let appNW = MKMapPointForCoordinate(ll(90, -180))
let appSE = MKMapPointForCoordinate(ll(-90, 180))

MKMapPointForCoordinate(ll(90, -180))
MKMapPointForCoordinate(ll(-90, 180))

MKCoordinateForMapPoint(MKMapPoint(x: 0, y: 439_674.402483538))
MKCoordinateForMapPoint(MKMapPoint(x: 268_435_456, y: 267_995_781.597516))

println("Equivalent Spherical point ([0, 0] origin)")
let sphP = Projection.projectedMetersFromCoordinate(c)

println("Spherical world layout")
let sphSize = Projection.SizeInMeters
let sphMetersPerPixelEquatorZ0 = Projection.metersPerPixelAtLatitude(0, zoom: 0)
let sphMetersPerPixelPoleZ0 = Projection.metersPerPixelAtLatitude(90, zoom: 0)
let sphMetersPerPixelEquatorZ15 = Projection.metersPerPixelAtLatitude(0, zoom: 15)
let sphMetersPerPixelPoleZ15 = Projection.metersPerPixelAtLatitude(90, zoom: 15)
let sphMetersPerPixelEquatorZ20 = Projection.metersPerPixelAtLatitude(0, zoom: 20)
let sphMetersPerPixelPoleZ20 = Projection.metersPerPixelAtLatitude(90, zoom: 20)
let sphNW = Projection.projectedMetersFromCoordinate(ll(90, -180))
let sphSE = Projection.projectedMetersFromCoordinate(ll(-90, 180))

let c1 = Projection.mapPointForCoordinate(c)
Projection.coordinateForMapPoint(c1)

let p1 = Projection.mapPointForCoordinate(ll(-14.2342342, -84.2342342))
Projection.coordinateForMapPoint(p1)

let p2 = Projection.mapPointForCoordinate(ll(45, -122))
Projection.coordinateForMapPoint(p2)

let p3 = Projection.mapPointForCoordinate(ll(30.566792, 135.9283243))
Projection.coordinateForMapPoint(p3)

let p4 = Projection.mapPointForCoordinate(ll(-64.2342342, 111.234234323))
Projection.coordinateForMapPoint(p4)

Projection.mapPointForCoordinate(ll(90, -180))
Projection.mapPointForCoordinate(ll(-90, 180))

MKMetersBetweenMapPoints(MKMapPointForCoordinate(ll(45, -122)), MKMapPointForCoordinate(ll(0, 0)))
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(0, 0)), method: .Haversine)
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(0, 0)), method: .SphericalCosine)
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(0, 0)), method: .Apple)

MKMetersBetweenMapPoints(MKMapPointForCoordinate(ll(45, -122)), MKMapPointForCoordinate(ll(45.0001, -122.0001)))
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(45.0001, -122.0001)), method: .Haversine)
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(45.0001, -122.0001)), method: .SphericalCosine)
Projection.metersBetweenMapPoints(Projection.mapPointForCoordinate(ll(45, -122)), b: Projection.mapPointForCoordinate(ll(45.0001, -122.0001)), method: .Apple)

let mapWidth: Double = 500
let mapHeight: Double = 300

let map = MKMapView(frame: CGRect(x: 0, y: 0, width: mapWidth, height: mapHeight))
map.region = MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 1.1, longitudeDelta: 1.1))
let zoom = Projection.zoomForScale(map.visibleMapRect.size.width / MKMapSizeWorld.width)
let zoom2 = Projection.zoomForScale(map.visibleMapRect.size.height / MKMapSizeWorld.height)
let mpp = Projection.metersPerPixelAtLatitude(c.latitude, zoom: zoom)

let topLeftX = Projection.projectedMetersFromCoordinate(c).x - ((mapWidth / 2) * mpp)
let topLeftY = Projection.projectedMetersFromCoordinate(c).y + ((mapHeight / 2) * mpp)
let topLeft = Projection.coordinateFromProjectedMeters(PMapPoint(x: topLeftX, y: topLeftY))

let bottomRightX = Projection.projectedMetersFromCoordinate(c).x + ((mapWidth / 2) * mpp)
let bottomRightY = Projection.projectedMetersFromCoordinate(c).y - ((mapHeight / 2) * mpp)
let bottomRight = Projection.coordinateFromProjectedMeters(PMapPoint(x: bottomRightX, y: bottomRightY))

let computedBounds = [ topLeft, bottomRight ]

let knownBounds = [ map.convertPoint(CGPoint(x: 0, y: 0), toCoordinateFromView:map), map.convertPoint(CGPoint(x: map.bounds.size.width, y: map.bounds.size.height), toCoordinateFromView:map) ]
map.region
map.region.center.latitude + map.region.span.latitudeDelta / 2
map.region.center.longitude - map.region.span.longitudeDelta / 2






