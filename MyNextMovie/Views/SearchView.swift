import SwiftData
import SwiftUI

/// How long to wait after the last keystroke before searching.
private let searchDelayAfterTyping = Duration.milliseconds(300)

private let searchInputKeySeparator = "|"

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var wishViewModel: WishSearchViewModel
    @State private var isShowingAIResults = false
    @State private var wishSearchTask: Task<Void, Never>?
    private let loadDetails: MovieDetailsLoader
    @Environment(\.modelContext) private var modelContext

    init(
        viewModel: SearchViewModel, wishViewModel: WishSearchViewModel,
        loadDetails: @escaping MovieDetailsLoader
    ) {
        self.loadDetails = loadDetails
        _viewModel = State(initialValue: viewModel)
        _wishViewModel = State(initialValue: wishViewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                genreFilter
                aiSearchHeader
                content.frame(maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title or keyword")
            .onSubmit(of: .search, askAI)
            .onChange(of: viewModel.query) { resetAISearch() }
            .onChange(of: viewModel.selectedGenreId) { resetAISearch() }
            .onDisappear { wishSearchTask?.cancel() }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie, loadDetails: loadDetails)
            }
            .task(id: searchInputKey(viewModel.query, viewModel.selectedGenreId)) {
                await searchAfterPause()
            }
        }
    }

    private var genreFilter: some View {
        GenreFilter(selectedGenreId: viewModel.selectedGenreId, toggleGenre: viewModel.toggleGenre)
    }

    @ViewBuilder
    private var content: some View {
        if isShowingAIResults { aiContent } else { plainContent }
    }

    @ViewBuilder
    private var plainContent: some View {
        switch viewModel.state {
        case .idle:
            SearchStartView { query in
                viewModel.query = query
                recordSearch(modelContext, query: query, now: .now)
            }
        case .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: viewModel.movies, query: viewModel.query)
        case .failed:
            ErrorView(title: "Search failed", message: viewModel.errorMessage) {
                Task { await viewModel.search() }
            }
        }
    }

    @ViewBuilder
    private var aiSearchHeader: some View {
        if isShowingAIResults {
            aiSearchSummary
        } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            askAIButton
        }
    }

    private var askAIButton: some View {
        Button(action: askAI) { Label("Ask AI", systemImage: symbolNameWish) }
            .buttonStyle(.bordered).disabled(wishViewModel.state == .loading)
            .padding(.horizontal).padding(.bottom, spacingSmall)
    }

    private var aiSearchSummary: some View {
        Text(
            wishViewModel.isPlainSearch
                ? wishViewModel.plainSearchReason : filtersSummary(wishViewModel.filters)
        )
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal).padding(.bottom, spacingSmall)
    }

    @ViewBuilder
    private var aiContent: some View {
        switch wishViewModel.state {
        case .idle, .loading:
            ProgressView("Searching…")
        case .loaded:
            SearchResults(movies: wishViewModel.movies, query: wishViewModel.wish)
        case .failed:
            ErrorView(title: "Search failed", message: wishViewModel.errorMessage, retry: askAI)
        }
    }

    private func askAI() {
        let wish = limitedMovieWish(viewModel.query)
        guard !wish.isEmpty && wishViewModel.state != .loading else { return }
        recordSearch(modelContext, query: wish, now: .now)
        wishViewModel.wish = wish
        isShowingAIResults = true
        wishSearchTask = Task { await wishViewModel.search() }
    }

    private func resetAISearch() {
        isShowingAIResults = false
        wishSearchTask?.cancel()
    }

    /// Waits until the user stops typing. Every keystroke cancels the previous wait.
    private func searchAfterPause() async {
        try? await Task.sleep(for: searchDelayAfterTyping)
        if Task.isCancelled {
            return
        }
        await viewModel.search()
    }
}

/// Changes whenever the search input changes, which restarts the search task.
private func searchInputKey(_ query: String, _ selectedGenreId: Int) -> String {
    return String(selectedGenreId) + searchInputKeySeparator + query
}

/// Every genre from `genreTable` as a chip in one row that scrolls sideways.
/// Tapping a chip selects its genre, tapping it again clears the selection.
private struct GenreFilter: View {
    let selectedGenreId: Int
    let toggleGenre: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: spacingSmall) {
            ForEach(genreTable) { genre in
                genreFilterChip(genre.id)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, spacingSmall)
    }

    private func genreFilterChip(_ genreId: Int) -> some View {
        Button {
            toggleGenre(genreId)
        } label: {
            GenreChip(genreId: genreId, isSelected: genreId == selectedGenreId)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchStartView: View {
    let selectQuery: (String) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SearchHistoryEntry.searchedAt, order: .reverse) private var entries:
        [SearchHistoryEntry]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "Find a movie", systemImage: symbolNameSearch,
                description: Text("Search by title or keyword, or pick a genre.")
            )
        } else {
            history
        }
    }

    private var history: some View {
        List {
            Section {
                rows
            } header: {
                historyHeader
            }
        }
        .listStyle(.plain)
    }

    private var rows: some View {
        ForEach(entries) { entry in
            Button {
                selectQuery(entry.query)
            } label: {
                Label(entry.query, systemImage: symbolNameSearchHistory)
            }
        }
    }

    private var historyHeader: some View {
        HStack {
            Text("Recent Searches")
            Spacer()
            Button("Clear") { clearSearchHistory(modelContext) }
        }
    }
}

#Preview {
    SearchView(
        viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
        wishViewModel: WishSearchViewModel(
            parseWish: chosenWishParser(), searchByFilters: searchTMDBMoviesByFilters,
            searchByText: searchTMDBMovies
        ), loadDetails: fetchMovieDetails
    )
    .modelContainer(for: storedModelTypes, inMemory: true)
}
