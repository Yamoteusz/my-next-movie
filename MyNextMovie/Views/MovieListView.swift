import SwiftData
import SwiftUI

private let gridMinimumColumnWidth: CGFloat = 150

struct MovieListView: View {
    @State private var viewModel: MovieListViewModel
    private let loadDetails: MovieDetailsLoader

    init(viewModel: MovieListViewModel, loadDetails: @escaping MovieDetailsLoader) {
        self.loadDetails = loadDetails
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Next Movie")
                .navigationDestination(for: Movie.self, destination: detailView)
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private func detailView(_ movie: Movie) -> some View {
        MovieDetailView(movie: movie, loadDetails: loadDetails)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingGrid
        case .loaded:
            loadedGrid
        case .failed:
            ErrorView(title: "Could not load movies", message: viewModel.errorMessage) {
                Task { await viewModel.load() }
            }
        }
    }

    /// Sample movies drawn as gray shapes while the real ones load.
    private var loadingGrid: some View {
        MovieGrid(title: "Popular", movies: makePlaceholderMovies())
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var loadedGrid: some View {
        if viewModel.movies.isEmpty {
            ContentUnavailableView("No movies", systemImage: symbolNameMovies)
        } else {
            MovieGrid(title: "Popular", movies: viewModel.movies)
        }
    }
}

struct MovieGrid: View {
    let title: String
    let movies: [Movie]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacingLarge) {
                Text(title).font(.title2.bold())
                grid
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: gridMinimumColumnWidth), spacing: spacingLarge)],
            spacing: spacingExtraLarge
        ) {
            ForEach(movies) { movie in
                MovieGridItem(movie: movie)
            }
        }
    }
}

/// One cell of the grid. Tapping it opens the movie details.
private struct MovieGridItem: View {
    let movie: Movie

    var body: some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie)
        }
        .buttonStyle(.plain)
    }
}

private let placeholderMovieCount = 6
private let placeholderMovieTitle = "Movie title"

private func makePlaceholderMovies() -> [Movie] {
    return (0..<placeholderMovieCount).map { id in
        Movie(
            id: id, title: placeholderMovieTitle, overview: "", releaseDate: "2000",
            posterPath: nil,
            voteAverage: 0, genreIds: [])
    }
}

#Preview {
    MovieListView(
        viewModel: MovieListViewModel(loadMovies: fetchPopularMovies),
        loadDetails: fetchMovieDetails
    )
    .modelContainer(for: storedModelTypes, inMemory: true)
}
