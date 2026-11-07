import MapKit
import SwiftUI

private let cinemaMapHeight: CGFloat = 230

struct CinemaDetailView: View {
    @State var viewModel: CinemaDetailViewModel
    @State private var lookAroundScene: MKLookAroundScene?

    var body: some View {
        List {
            Section { routeMap.listRowInsets(EdgeInsets()) }
            addressSection
            directionsSection
            contactSection
            if let lookAroundScene { lookAroundSection(lookAroundScene) }
        }
        .navigationTitle(viewModel.cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.travelMode) { await viewModel.loadRoute() }
        .task { lookAroundScene = await findLookAroundScene(viewModel.cinema) }
    }

    private var routeMap: some View {
        Map {
            Marker(
                viewModel.cinema.name, systemImage: symbolNameCinema,
                coordinate: cinemaCoordinate(viewModel.cinema))
            if viewModel.routeState == .loaded {
                MapPolyline(viewModel.route.line).stroke(.blue, lineWidth: 5)
            }
            if viewModel.userLocation.isKnown { UserAnnotation() }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: cinemaMapHeight)
    }

    private var addressSection: some View {
        Section("Address") {
            Text(viewModel.cinema.address)
            if viewModel.userLocation.isKnown { distanceLabel }
        }
    }

    private var distanceLabel: some View {
        Text(
            formattedDistance(distanceInMeters(from: viewModel.userLocation, to: viewModel.cinema))
        )
        .foregroundStyle(.secondary)
    }

    private var directionsSection: some View {
        Section("Way There") {
            travelModePicker
            routeStatus
        }
    }

    private var travelModePicker: some View {
        Picker("Travel mode", selection: $viewModel.travelMode) {
            Label("Walk", systemImage: symbolNameWalking).tag(TravelMode.walking)
            Label("Drive", systemImage: symbolNameDriving).tag(TravelMode.driving)
        }
        .pickerStyle(.segmented).disabled(!viewModel.canFindRoute)
    }

    @ViewBuilder
    private var routeStatus: some View {
        if !viewModel.canFindRoute {
            Text("Turn on location to see distances and routes.").foregroundStyle(.secondary)
        } else {
            availableRouteStatus
        }
    }

    @ViewBuilder
    private var availableRouteStatus: some View {
        switch viewModel.routeState {
        case .idle, .loading:
            ProgressView("Finding route…")
        case .loaded:
            Text(routeSummary(viewModel.route))
        case .failed:
            Text(viewModel.errorMessage).foregroundStyle(.secondary)
            Button("Try again") { Task { await viewModel.loadRoute() } }
        }
    }

    private var contactSection: some View {
        Section {
            Button {
                openCinemaInMaps(viewModel.cinema, travelMode: viewModel.travelMode)
            } label: {
                Label("Directions in Maps", systemImage: symbolNameDirections)
            }
            phoneLink
            websiteLink
        }
    }

    @ViewBuilder
    private var phoneLink: some View {
        if let address = phoneURL(viewModel.cinema) {
            Link(destination: address) {
                Label(viewModel.cinema.phoneNumber, systemImage: symbolNamePhone)
            }
        }
    }

    @ViewBuilder
    private var websiteLink: some View {
        if let address = websiteURL(viewModel.cinema) {
            Link(destination: address) { Label("Website", systemImage: symbolNameWebsite) }
        }
    }

    private func lookAroundSection(_ scene: MKLookAroundScene) -> some View {
        Section("Look Around") {
            LookAroundPreview(initialScene: scene).frame(height: cinemaMapHeight)
        }
    }
}

#Preview {
    NavigationStack {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: wroclawCinemas[0], userLocation: fallbackUserLocation,
                findRoute: { _, _, _ in noRoute }
            ))
    }
}
