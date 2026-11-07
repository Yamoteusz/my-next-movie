import CoreLocation
import Foundation

/// Distance of a cinema before the app knows where the user is.
nonisolated let unknownDistance: CLLocationDistance = -1

/// A cinema in Wrocław, a plain struct,
/// so the views and tests do not depend on `MKMapItem`.
nonisolated struct Cinema: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let address: String  // empty when unknown
    let phoneNumber: String  // empty when unknown
    let website: String  // empty when unknown
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var distanceInMeters = unknownDistance
}

/// Where the user is. `isKnown` is false when the app does not know it.
nonisolated struct UserLocation: Equatable, Sendable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let isKnown: Bool
}

let noCinemaSelected = ""
let cinemaNotFound = -1
let fallbackCoordinate = CLLocationCoordinate2D(latitude: 51.1100, longitude: 17.0320)
let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude, longitude: fallbackCoordinate.longitude, isKnown: false
)

func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

func userCoordinate(_ location: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
}

func distanceInMeters(from userLocation: UserLocation, to cinema: Cinema) -> CLLocationDistance {
    guard userLocation.isKnown else { return unknownDistance }
    let start = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    let end = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    return start.distance(from: end)
}

func cinemasSortedByDistance(_ cinemas: [Cinema], from location: UserLocation) -> [Cinema] {
    return cinemas.map { cinema in
        var measured = cinema
        measured.distanceInMeters = distanceInMeters(from: location, to: cinema)
        return measured
    }.sorted(by: isCloser)
}

func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        if first.distanceInMeters == unknownDistance { return false }
        if second.distanceInMeters == unknownDistance { return true }
        return first.distanceInMeters < second.distanceInMeters
    }
    if first.name != second.name { return first.name < second.name }
    return first.id < second.id
}

func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    return cinemas.firstIndex { $0.id == cinemaId } ?? cinemaNotFound
}

func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

func formattedDistance(_ distance: CLLocationDistance) -> String {
    guard distance.isFinite && distance >= 0 else { return "" }
    if distance < 1000 { return "\(Int(distance.rounded())) m" }
    return String(format: "%.1f km", locale: Locale(identifier: "en_US_POSIX"), distance / 1000)
}

func phoneURL(_ cinema: Cinema) -> URL? {
    let number = cinema.phoneNumber.filter { $0.isASCII && $0.isNumber }
    guard !number.isEmpty else { return nil }
    let prefix = cinema.phoneNumber.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" : ""
    return URL(string: "tel:" + prefix + number)
}

func hasPhoneNumber(_ cinema: Cinema) -> Bool { return phoneURL(cinema) != nil }

func websiteURL(_ cinema: Cinema) -> URL? {
    guard let address = URL(string: cinema.website),
        address.scheme == "https" || address.scheme == "http", address.host != nil
    else { return nil }
    return address
}

func hasWebsite(_ cinema: Cinema) -> Bool { return websiteURL(cinema) != nil }
