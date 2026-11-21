import Foundation
import Observation

@MainActor
@Observable
final class WishSearchViewModel {
    var wish = ""
    private(set) var state = LoadState.idle
    private(set) var movies: [Movie] = []
    private(set) var errorMessage = ""
    private(set) var filters = noMovieFilters
    private(set) var plainSearchReason = ""

    private let parseWish: MovieWishParser
    private let searchByFilters: FilteredMovieSearch
    private let searchByText: MovieSearch
    private let currentYear: Int
    private var searchVersion = 0

    init(
        parseWish: @escaping MovieWishParser, searchByFilters: @escaping FilteredMovieSearch,
        searchByText: @escaping MovieSearch, currentYear: Int = yearOfToday()
    ) {
        self.parseWish = parseWish
        self.searchByFilters = searchByFilters
        self.searchByText = searchByText
        self.currentYear = currentYear
    }

    var isPlainSearch: Bool { return !plainSearchReason.isEmpty }
    var canSearch: Bool {
        return !wish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state != .loading
    }

    func search() async {
        let text = limitedMovieWish(wish)
        guard !text.isEmpty else { return }
        searchVersion += 1
        let version = searchVersion
        state = .loading
        movies = []
        errorMessage = ""
        filters = noMovieFilters
        plainSearchReason = ""
        do {
            let parsed = try await parseFilters(text)
            try Task.checkCancellation()
            guard version == searchVersion else { return }
            filters = parsed.filters
            plainSearchReason = parsed.reason
            let results: [Movie]
            if isPlainSearch {
                results = try await searchByText(text, noGenreId)
            } else {
                results = try await searchByFilters(filters)
            }
            try Task.checkCancellation()
            guard version == searchVersion else { return }
            movies = results
            state = .loaded
        } catch {
            guard version == searchVersion else { return }
            if Task.isCancelled || error is CancellationError {
                state = .idle
            } else {
                errorMessage = error.localizedDescription
                state = .failed
            }
        }
    }

    private func parseFilters(_ text: String) async throws -> (
        filters: MovieFilters, reason: String
    ) {
        do {
            let filters = validatedFilters(try await parseWish(text), currentYear: currentYear)
            if hasAnyFilter(filters) { return (filters, "") }
            return (noMovieFilters, "AI found no usable filters. Searching by title.")
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            return (noMovieFilters, error.localizedDescription + " Searching by title.")
        }
    }
}
