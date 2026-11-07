import CoreLocation
import MapKit
import Testing

@testable import MyNextMovie

@MainActor
struct CinemaMapViewModelTests {
    @Test func showsCinemasAtOnceByName() {
        let model = CinemaMapViewModel(cinemas: testCinemas, findUserLocation: { testUserLocation })
        #expect(namesOf(model.cinemas) == namesOf(testCinemas).sorted())
        #expect(!model.userLocation.isKnown)
        #expect(!model.isLocationUnavailable)
    }

    @Test func sortsByDistanceOnceUserIsFound() async {
        let model = CinemaMapViewModel(cinemas: testCinemas, findUserLocation: { testUserLocation })
        await model.locateUser()
        #expect(model.cinemas.first?.id == "dcf")
        #expect(model.userLocation == testUserLocation)
    }

    @Test func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let model = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { fallbackUserLocation },
            lastKnownLocation: { testUserLocation }
        )
        await model.locateUser()
        #expect(model.userLocation == testUserLocation)
        #expect(model.cinemas.first?.id == "dcf")
        #expect(!model.isLocationUnavailable)
    }

    @Test func freshLocationReplacesLastKnownOne() async {
        let fresh = UserLocation(
            latitude: testCinemaHelios.latitude, longitude: testCinemaHelios.longitude,
            isKnown: true)
        let model = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { fresh },
            lastKnownLocation: { testUserLocation }
        )
        await model.locateUser()
        #expect(model.userLocation == fresh)
        #expect(model.cinemas.first?.id == testCinemaHelios.id)
        #expect(model.cinemas.first?.distanceInMeters == 0)
    }

    @Test func saysWhenLocationIsUnavailable() async {
        let model = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { fallbackUserLocation })
        await model.locateUser()
        #expect(model.isLocationUnavailable)
        #expect(!model.isLocating)
        #expect(namesOf(model.cinemas) == namesOf(testCinemas).sorted())
    }

    @Test func asksForLocationOnlyOnce() async {
        var calls = 0
        let model = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: {
                calls += 1
                return testUserLocation
            })
        await model.locateUserIfNeeded()
        await model.locateUserIfNeeded()
        #expect(calls == 1)
    }

    @Test func togglesSelection() {
        let model = CinemaMapViewModel(cinemas: testCinemas, findUserLocation: { testUserLocation })
        model.toggleCinema("dcf")
        #expect(model.selectedCinemaId == "dcf")
        model.toggleCinema("dcf")
        #expect(model.selectedCinemaId == noCinemaSelected)
        model.toggleCinema("missing")
        #expect(model.selectedCinemaId == noCinemaSelected)
    }
}

@MainActor
struct CinemaDetailViewModelTests {
    @Test func findsNoRouteWithoutLocation() async {
        var calls = 0
        let model = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: fallbackUserLocation,
            findRoute: { _, _, _ in
                calls += 1
                return noRoute
            }
        )
        await model.loadRoute()
        #expect(!model.canFindRoute)
        #expect(model.routeState == .idle)
        #expect(calls == 0)
    }

    @Test func findsRouteForSelectedTravelMode() async {
        var mode: TravelMode?
        var receivedCinema: Cinema?
        var location: UserLocation?
        let model = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: testUserLocation,
            findRoute: { user, cinema, travel in
                location = user
                receivedCinema = cinema
                mode = travel
                return testRoute()
            }
        )
        model.travelMode = .driving
        await model.loadRoute()
        #expect(mode == .driving)
        #expect(receivedCinema?.id == "dcf")
        #expect(location == testUserLocation)
        #expect(model.routeState == .loaded)
        #expect(model.route.distanceInMeters == 950)
    }

    @Test func showsErrorWhenRouteFails() async {
        let model = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: testUserLocation,
            findRoute: { _, _, _ in throw NoRouteFound() }
        )
        await model.loadRoute()
        #expect(model.routeState == .failed)
        #expect(model.errorMessage == "Maps found no way to this cinema.")
    }

    @Test func routeSummaryHasTimeAndDistance() {
        #expect(formattedTravelTime(720) == "12 min")
        #expect(routeSummary(testRoute()) == "12 min · 950 m")
        #expect(routeSummary(noRoute).isEmpty)
    }

    @Test func olderRouteCannotReplaceNewTravelMode() async {
        var finishWalking: CheckedContinuation<CinemaRoute, Never>?
        let model = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: testUserLocation,
            findRoute: { _, _, mode in
                if mode == .walking { return await withCheckedContinuation { finishWalking = $0 } }
                return CinemaRoute(line: MKPolyline(), distanceInMeters: 2000, travelTime: 300)
            }
        )
        let walking = Task { await model.loadRoute() }
        while finishWalking == nil { await Task.yield() }
        model.travelMode = .driving
        await model.loadRoute()
        finishWalking?.resume(returning: testRoute())
        await walking.value
        #expect(model.route.distanceInMeters == 2000)
        #expect(model.routeState == .loaded)
    }
}

@MainActor
private func testRoute() -> CinemaRoute {
    return CinemaRoute(line: MKPolyline(), distanceInMeters: 950, travelTime: 720)
}
