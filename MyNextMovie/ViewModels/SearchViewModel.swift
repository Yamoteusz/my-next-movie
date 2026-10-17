import Foundation
import Observation

/// A class only because SwiftUI's @Observable requires one.
@Observable
final class SearchViewModel {
    var query = ""
    var selectedGenreId = noGenreId
    private(set) var state = LoadState.idle
    private(set) var movies: [Movie] = []
    private(set) var errorMessage = ""

    private let searchMovies: MovieSearch
    private var searchVersion = 0

    init(searchMovies: @escaping MovieSearch) {
        self.searchMovies = searchMovies
    }

    func search() async {
        searchVersion += 1
        let version = searchVersion
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let genreId = selectedGenreId
        if trimmedQuery.isEmpty && selectedGenreId == noGenreId {
            movies = []
            errorMessage = ""
            state = .idle
            return
        }
        state = .loading
        errorMessage = ""
        do {
            let results = try await searchMovies(trimmedQuery, genreId)
            guard version == searchVersion && !Task.isCancelled else { return }
            movies = results
            state = .loaded
        } catch {
            guard version == searchVersion && !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    /// Selects the genre, or clears the selection when the genre is already selected.
    func toggleGenre(_ genreId: Int) {
        selectedGenreId = selectedGenreId == genreId ? noGenreId : genreId
    }
}
