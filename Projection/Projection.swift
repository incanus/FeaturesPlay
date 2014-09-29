import CoreLocation

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
