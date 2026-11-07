import MapKit
import Observation

@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation = fallbackUserLocation
    private(set) var selectedCinemaId = noCinemaSelected
    private(set) var isLocating = false
    var visibleRegion = wroclawMapRegion
    private var hasLocated = false
    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader

    init(
        cinemas: [Cinema], findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        self.cinemas = cinemasSortedByDistance(cinemas, from: fallbackUserLocation)
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
    }

    var isLocationUnavailable: Bool { return hasLocated && !isLocating && !userLocation.isKnown }

    func locateUserIfNeeded() async {
        guard !hasLocated else { return }
        await locateUser()
    }

    func locateUser() async {
        guard !isLocating else { return }
        hasLocated = true
        isLocating = true
        defer { isLocating = false }
        applyLocation(lastKnownLocation())
        let location = await findUserLocation()
        guard !Task.isCancelled else { return }
        applyLocation(location)
    }

    private func applyLocation(_ location: UserLocation) {
        guard location.isKnown else { return }
        userLocation = location
        cinemas = cinemasSortedByDistance(cinemas, from: location)
    }

    func toggleCinema(_ cinemaId: String) {
        guard containsCinema(cinemas, cinemaId: cinemaId) else { return }
        selectedCinemaId = selectedCinemaId == cinemaId ? noCinemaSelected : cinemaId
    }
}
