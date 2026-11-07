import MapKit

typealias UserLocationFinder = @MainActor () async -> UserLocation
typealias LastKnownLocationReader = @MainActor () -> UserLocation

enum TravelMode: String, CaseIterable { case walking, driving }

typealias CinemaRouteFinder =
    @MainActor (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

struct CinemaRoute {
    let line: MKPolyline
    let distanceInMeters: CLLocationDistance
    let travelTime: TimeInterval
}

let noRoute = CinemaRoute(line: MKPolyline(), distanceInMeters: unknownDistance, travelTime: 0)

struct NoRouteFound: LocalizedError {
    var errorDescription: String? { return "Maps found no way to this cinema." }
}

@MainActor
func findMapKitRoute(userLocation: UserLocation, cinema: Cinema, travelMode: TravelMode)
    async throws -> CinemaRoute
{
    guard userLocation.isKnown else { throw NoRouteFound() }
    let request = MKDirections.Request()
    request.source = MKMapItem(
        location: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude),
        address: nil
    )
    request.destination = mapItemForCinema(cinema)
    request.transportType = transportTypeForMapKit(travelMode)
    let response = try await MKDirections(request: request).calculate()
    try Task.checkCancellation()
    guard let route = response.routes.first else { throw NoRouteFound() }
    return CinemaRoute(
        line: route.polyline, distanceInMeters: route.distance, travelTime: route.expectedTravelTime
    )
}

func mapItemForCinema(_ cinema: Cinema) -> MKMapItem {
    let location = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    let item = MKMapItem(
        location: location, address: MKAddress(fullAddress: cinema.address, shortAddress: nil))
    item.name = cinema.name
    item.phoneNumber = cinema.phoneNumber.isEmpty ? nil : cinema.phoneNumber
    item.url = websiteURL(cinema)
    return item
}

func transportTypeForMapKit(_ travelMode: TravelMode) -> MKDirectionsTransportType {
    return travelMode == .walking ? .walking : .automobile
}

func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let mode =
        travelMode == .walking
        ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
    mapItemForCinema(cinema).openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
}

func findLookAroundScene(_ cinema: Cinema) async -> MKLookAroundScene? {
    let request = MKLookAroundSceneRequest(coordinate: cinemaCoordinate(cinema))
    return try? await request.scene
}
