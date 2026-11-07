import Foundation
import Observation

@Observable
final class CinemaDetailViewModel {
    let cinema: Cinema
    let userLocation: UserLocation
    var travelMode = TravelMode.walking
    private(set) var routeState = LoadState.idle
    private(set) var route = noRoute
    private(set) var errorMessage = ""
    private let findRoute: CinemaRouteFinder
    private var routeVersion = 0

    init(cinema: Cinema, userLocation: UserLocation, findRoute: @escaping CinemaRouteFinder) {
        self.cinema = cinema
        self.userLocation = userLocation
        self.findRoute = findRoute
    }

    var canFindRoute: Bool { return userLocation.isKnown }

    func loadRoute() async {
        guard canFindRoute else { return }
        routeVersion += 1
        let version = routeVersion
        let mode = travelMode
        routeState = .loading
        route = noRoute
        errorMessage = ""
        do {
            let result = try await findRoute(userLocation, cinema, mode)
            guard !Task.isCancelled && version == routeVersion && mode == travelMode else { return }
            route = result
            routeState = .loaded
        } catch {
            guard !Task.isCancelled && version == routeVersion && mode == travelMode else { return }
            routeState = .failed
            errorMessage = error.localizedDescription
        }
    }
}

func formattedTravelTime(_ travelTime: TimeInterval) -> String {
    guard travelTime.isFinite && travelTime >= 0 else { return "" }
    return "\(max(1, Int((travelTime / 60).rounded(.up)))) min"
}

func routeSummary(_ route: CinemaRoute) -> String {
    guard route.distanceInMeters != unknownDistance else { return "" }
    return [formattedTravelTime(route.travelTime), formattedDistance(route.distanceInMeters)]
        .filter { !$0.isEmpty }.joined(separator: textSeparator)
}
