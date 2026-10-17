import SwiftUI

struct PopularMoviesPreview<Content: View>: View {
    @ViewBuilder let content: ([Movie]) -> Content
    @State private var viewModel = MovieListViewModel(loadMovies: fetchPopularMovies)

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .failed:
                Text(viewModel.errorMessage)
            case .loaded:
                loadedContent
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if viewModel.movies.isEmpty {
            ContentUnavailableView("No movies", systemImage: symbolNameMovies)
        } else {
            content(viewModel.movies)
        }
    }
}
