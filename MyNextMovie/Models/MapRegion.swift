import MapKit

let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 51.0956, longitude: 17.0230),
    latitudinalMeters: 15500, longitudinalMeters: 14000
)

func regionMoved(_ region: MKCoordinateRegion, to coordinate: CLLocationCoordinate2D)
    -> MKCoordinateRegion
{
    return MKCoordinateRegion(center: coordinate, span: region.span)
}

func isInRegion(_ coordinate: CLLocationCoordinate2D, _ region: MKCoordinateRegion) -> Bool {
    let longitudeDelta = abs(
        (coordinate.longitude - region.center.longitude).remainder(dividingBy: 360))
    return abs(coordinate.latitude - region.center.latitude) <= region.span.latitudeDelta / 2
        && longitudeDelta <= region.span.longitudeDelta / 2
}
