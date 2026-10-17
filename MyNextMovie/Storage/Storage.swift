import Foundation
import SwiftData

let maxSearchHistoryCount = 10

@MainActor
func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.movieId == movieId })
    return (try? context.fetch(descriptor)) ?? []
}

@MainActor
func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

@MainActor
func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let copies = fetchSavedMovies(context, movieId: movie.id)
    if copies.isEmpty {
        removeDeletionMark(context, movieId: movie.id)
        context.insert(SavedMovie(movie: movie, savedAt: now, isInCloud: false))
        return
    }
    for saved in copies {
        if saved.isInCloud { markMovieRemoved(context, movieId: movie.id) }
        context.delete(saved)
    }
}

@MainActor
func markMovieRemoved(_ context: ModelContext, movieId: Int) {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { $0.movieId == movieId })
    if ((try? context.fetch(descriptor)) ?? []).isEmpty {
        context.insert(RemovedSavedMovie(movieId: movieId))
    }
}

@MainActor
func removeDeletionMark(_ context: ModelContext, movieId: Int) {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { $0.movieId == movieId })
    for mark in (try? context.fetch(descriptor)) ?? [] { context.delete(mark) }
}

@MainActor
func clearSavedMovies(_ context: ModelContext) {
    for movie in (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? [] { context.delete(movie) }
    for mark in (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? [] {
        context.delete(mark)
    }
}

@MainActor
func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId, title: savedMovie.title, overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate, posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage, genreIds: savedMovie.genreIds
    )
}

@MainActor
func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    return savedMovies.map(movieFromSaved)
}

@MainActor
func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    let descriptor = FetchDescriptor<SearchHistoryEntry>(predicate: #Predicate { $0.query == text })
    if let entry = try? context.fetch(descriptor).first {
        entry.searchedAt = now
    } else {
        context.insert(SearchHistoryEntry(query: text, searchedAt: now))
    }
    removeOldSearches(context)
}

@MainActor
private func historyDescriptor() -> FetchDescriptor<SearchHistoryEntry> {
    return FetchDescriptor<SearchHistoryEntry>(sortBy: [
        SortDescriptor(\.searchedAt, order: .reverse)
    ])
}

@MainActor
private func removeOldSearches(_ context: ModelContext) {
    let entries = (try? context.fetch(historyDescriptor())) ?? []
    for entry in entries.dropFirst(maxSearchHistoryCount) { context.delete(entry) }
}

@MainActor
func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    return Array(((try? context.fetch(historyDescriptor())) ?? []).prefix(maxSearchHistoryCount))
}

@MainActor
func clearSearchHistory(_ context: ModelContext) {
    for entry in (try? context.fetch(historyDescriptor())) ?? [] { context.delete(entry) }
}

@MainActor
func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    let descriptor = FetchDescriptor<CachedResponse>(predicate: #Predicate { $0.key == key })
    if let entry = try? context.fetch(descriptor).first {
        entry.data = data
        entry.fetchedAt = now
    } else {
        context.insert(CachedResponse(key: key, data: data, fetchedAt: now))
    }
}

@MainActor
func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    let descriptor = FetchDescriptor<CachedResponse>(predicate: #Predicate { $0.key == key })
    return (try? context.fetch(descriptor).first?.data) ?? Data()
}

@MainActor
func fetchWithCacheFallback(
    _ context: ModelContext, key: String, fetch: @MainActor () async throws -> Data
) async throws -> Data {
    do {
        let data = try await fetch()
        storeCachedResponse(context, key: key, data: data, now: .now)
        return data
    } catch {
        if error is CancellationError { throw error }
        let data = cachedResponseData(context, key: key)
        guard !data.isEmpty else { throw error }
        return data
    }
}
