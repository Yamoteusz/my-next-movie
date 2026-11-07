import MapKit
import SwiftUI

enum CinemaMapPlacement { case tab, sheet }

struct CinemaMapView: View {
    @State private var viewModel: CinemaMapViewModel
    private let findRoute: CinemaRouteFinder
    private let placement: CinemaMapPlacement
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCinemaId: String?
    @State private var path: [Cinema] = []

    init(
        viewModel: CinemaMapViewModel, findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        _viewModel = State(initialValue: viewModel)
        _cameraPosition = State(initialValue: .region(viewModel.visibleRegion))
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $path) {
            content.navigationTitle("Cinemas")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Cinema.self, destination: cinemaDetails)
                .toolbar { if placement == .sheet { Button("Done") { dismiss() } } }
        }
        .task { await viewModel.locateUserIfNeeded() }
        .onChange(of: selectedCinemaId) { _, selected in updateSelection(selected) }
        .onChange(of: viewModel.selectedCinemaId) { _, selected in
            selectedCinemaId = selected.isEmpty ? nil : selected
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            map.containerRelativeFrame(.vertical) { length, _ in length * 0.45 }
            if viewModel.isLocationUnavailable { locationNotice }
            if viewModel.isLocating { ProgressView("Finding your location…").padding(spacingSmall) }
            cinemaList
        }
    }

    private var map: some View {
        Map(position: $cameraPosition, selection: $selectedCinemaId) { markers }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.visibleRegion = context.region
            }
    }

    @MapContentBuilder
    private var markers: some MapContent {
        UserAnnotation()
        ForEach(viewModel.cinemas) { cinema in
            Marker(cinema.name, systemImage: symbolNameCinema, coordinate: cinemaCoordinate(cinema))
                .tag(cinema.id)
        }
    }

    private var locationNotice: some View {
        Label("Turn on location to see distances and routes.", systemImage: symbolNameLocationOff)
            .font(.caption).foregroundStyle(.secondary).padding(spacingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cinemaList: some View {
        ScrollViewReader { reader in cinemaList(reader: reader) }
    }

    private func cinemaList(reader: ScrollViewProxy) -> some View {
        List(viewModel.cinemas) { cinema in cinemaRow(cinema) }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedCinemaId) { _, selected in
                scrollToCinema(selected, reader: reader)
            }
    }

    private func cinemaRow(_ cinema: Cinema) -> some View {
        HStack(spacing: spacingMedium) {
            Button {
                selectRow(cinema)
            } label: {
                CinemaListLabel(cinema: cinema)
            }
            .buttonStyle(.plain)
            Button {
                path.append(cinema)
            } label: {
                Image(systemName: symbolNameDetails)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Details of \(cinema.name)")
        }
        .padding(.vertical, spacingExtraSmall)
        .listRowBackground(
            viewModel.selectedCinemaId == cinema.id ? Color.accentColor.opacity(0.12) : Color.clear
        )
        .id(cinema.id)
    }

    private func selectRow(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema.id)
        let region = regionMoved(viewModel.visibleRegion, to: cinemaCoordinate(cinema))
        viewModel.visibleRegion = region
        withAnimation { cameraPosition = .region(region) }
    }

    private func updateSelection(_ selected: String?) {
        let id = selected ?? noCinemaSelected
        guard id != viewModel.selectedCinemaId else { return }
        viewModel.toggleCinema(id.isEmpty ? viewModel.selectedCinemaId : id)
    }

    private func scrollToCinema(_ id: String, reader: ScrollViewProxy) {
        guard !id.isEmpty else { return }
        withAnimation { reader.scrollTo(id, anchor: .center) }
    }

    private func cinemaDetails(_ cinema: Cinema) -> some View {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: cinema, userLocation: viewModel.userLocation, findRoute: findRoute
            ))
    }
}

private struct CinemaListLabel: View {
    let cinema: Cinema

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraSmall) {
            Text(cinema.name).font(.headline)
            Text(cinema.address).font(.subheadline).foregroundStyle(.secondary)
            if cinema.distanceInMeters != unknownDistance {
                distanceLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var distanceLabel: some View {
        Text(formattedDistance(cinema.distanceInMeters)).font(.caption).foregroundStyle(.secondary)
    }
}

#Preview {
    CinemaMapView(
        viewModel: CinemaMapViewModel(
            cinemas: wroclawCinemas, findUserLocation: { fallbackUserLocation }),
        findRoute: { _, _, _ in noRoute }, placement: .sheet
    )
}
