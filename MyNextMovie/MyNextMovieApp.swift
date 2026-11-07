import SwiftData
import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: storedModelTypes)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppTabs(
            account: makeAccount(), loadMovies: loadPopularMoviesWithCache,
            loadDetails: loadDetailsWithCache
        )
    }

    private func makeAccount() -> AccountViewModel {
        let viewModel = AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: {
                try await syncSavedMovies(modelContext, cloud: supabaseSavedMoviesCloud)
            },
            clearSavedMovies: { clearSavedMovies(modelContext) }
        )
        #if DEBUG
            viewModel.email = testAccountEmail
            viewModel.password = testAccountPassword
        #endif
        return viewModel
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}

private struct AppTabs: View {
    @State var account: AccountViewModel
    let loadMovies: MovieLoader
    let loadDetails: MovieDetailsLoader
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<SavedMovie> { !$0.isInCloud }) private var pendingMovies: [SavedMovie]
    @Query private var removedMovies: [RemovedSavedMovie]

    private var pendingCount: Int { return pendingMovies.count + removedMovies.count }

    var body: some View {
        Group {
            if account.isSignedIn { tabs } else { SignInView(viewModel: account) }
        }
        .task { await account.syncSavedMovies() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await account.syncSavedMovies() } }
        }
        .onChange(of: pendingCount) { oldCount, newCount in
            if newCount > oldCount { Task { await account.syncSavedMovies() } }
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) { moviesTab }
            Tab("Saved", systemImage: symbolNameSaved) { SavedMoviesView(loadDetails: loadDetails) }
            Tab("Cinemas", systemImage: symbolNameCinema) { cinemaMap }
            Tab("Account", systemImage: symbolNameAccount) { AccountView(viewModel: account) }
            Tab("Search", systemImage: symbolNameSearch, role: .search) { searchTab }
        }
        .disabled(account.isSigningOut)
    }

    private var cinemaMap: some View {
        let viewModel = CinemaMapViewModel(
            cinemas: wroclawCinemas, findUserLocation: findUserLocation,
            lastKnownLocation: lastKnownUserLocation
        )
        return CinemaMapView(viewModel: viewModel, findRoute: findMapKitRoute, placement: .tab)
    }

    private var moviesTab: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: loadMovies), loadDetails: loadDetails)
    }

    private var searchTab: some View {
        SearchView(
            viewModel: SearchViewModel(searchMovies: searchTMDBMovies), loadDetails: loadDetails)
    }
}
