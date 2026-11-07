import CoreLocation

private let locationTimeout = Duration.seconds(10)

@MainActor
func findUserLocation() async -> UserLocation {
    return await withTaskGroup(of: UserLocation.self) { group in
        group.addTask { await freshUserLocation() }
        group.addTask {
            try? await Task.sleep(for: locationTimeout)
            return await fallbackUserLocation
        }
        let location = await group.next() ?? fallbackUserLocation
        group.cancelAll()
        return location
    }
}

@MainActor
private func freshUserLocation() async -> UserLocation {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if Task.isCancelled || update.authorizationDenied { return fallbackUserLocation }
            if let location = update.location, location.horizontalAccuracy >= 0 {
                return userLocationFrom(location)
            }
        }
    } catch { return fallbackUserLocation }
    return fallbackUserLocation
}

@MainActor
func lastKnownUserLocation() -> UserLocation {
    guard let location = CLLocationManager().location, location.horizontalAccuracy >= 0 else {
        return fallbackUserLocation
    }
    return userLocationFrom(location)
}

private func userLocationFrom(_ location: CLLocation) -> UserLocation {
    return UserLocation(
        latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
        isKnown: true
    )
}
