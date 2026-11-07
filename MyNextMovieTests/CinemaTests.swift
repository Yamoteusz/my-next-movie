import CoreLocation
import MapKit
import Testing

@testable import MyNextMovie

@MainActor
struct CinemaTests {
    @Test func sortsCinemasClosestFirst() {
        let cinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)
        #expect(
            cinemas.map(\.id) == ["dcf", "nowe-horyzonty", "multikino-pasaz", "helios-magnolia"])
    }

    @Test func measuresDistanceOfEveryCinema() {
        let cinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)
        #expect(cinemas.allSatisfy { $0.distanceInMeters > 0 })
        let dcf = cinemas.first
        #expect((dcf?.distanceInMeters ?? 0) > 700)
        #expect((dcf?.distanceInMeters ?? 0) < 900)
        #expect(testCinemas.allSatisfy { $0.distanceInMeters == unknownDistance })
    }

    @Test func sortsCinemasAtTheSameDistanceByName() {
        var first = testCinemaNoweHoryzonty
        var second = testCinemaDCF
        first.distanceInMeters = 100
        second.distanceInMeters = 100
        #expect([first, second].sorted(by: isCloser).map(\.id) == ["dcf", "nowe-horyzonty"])
    }

    @Test func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: "dcf") == 2)
        #expect(containsCinema(testCinemas, cinemaId: "dcf"))
        #expect(positionOfCinema(testCinemas, cinemaId: "missing") == cinemaNotFound)
        #expect(!containsCinema(testCinemas, cinemaId: "missing"))
    }

    @Test func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance).isEmpty)
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2400) == "2.4 km")
    }

    @Test func phoneLinkHasOnlyDigits() {
        #expect(phoneURL(testCinemaNoweHoryzonty)?.absoluteString == "tel:+48717864566")
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty))
    }

    @Test func noPhoneOrWebsiteMeansNoLink() {
        #expect(phoneURL(testCinemaHelios) == nil)
        #expect(!hasPhoneNumber(testCinemaHelios))
        #expect(websiteURL(testCinemaHelios) == nil)
        #expect(!hasWebsite(testCinemaHelios))
    }
}

@MainActor
struct WroclawCinemasTests {
    @Test func everyCinemaIsOnTheStartMap() {
        #expect(wroclawCinemas.count == 7)
        #expect(wroclawCinemas.allSatisfy { isInRegion(cinemaCoordinate($0), wroclawMapRegion) })
    }

    @Test func idsAreUnique() {
        #expect(Set(wroclawCinemas.map(\.id)).count == wroclawCinemas.count)
    }

    @Test func everyCinemaHasAddressAndWebsite() {
        #expect(wroclawCinemas.allSatisfy { !$0.address.isEmpty && hasWebsite($0) })
    }

    @Test func pointOutsideRegionIsNotOnTheMap() {
        let warsaw = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        #expect(!isInRegion(warsaw, wroclawMapRegion))
        let moved = regionMoved(wroclawMapRegion, to: warsaw)
        #expect(moved.center.latitude == warsaw.latitude)
        #expect(moved.span.latitudeDelta == wroclawMapRegion.span.latitudeDelta)
    }
}

@MainActor
struct MapKitConversionTests {
    @Test func mapItemForCinemaKeepsNameAndPosition() {
        let item = mapItemForCinema(testCinemaNoweHoryzonty)
        #expect(item.name == testCinemaNoweHoryzonty.name)
        #expect(item.location.coordinate.latitude == testCinemaNoweHoryzonty.latitude)
        #expect(item.location.coordinate.longitude == testCinemaNoweHoryzonty.longitude)
    }

    @Test func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}
