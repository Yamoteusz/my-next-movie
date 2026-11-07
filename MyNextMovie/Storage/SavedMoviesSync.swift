import Foundation
import SwiftData

@MainActor
func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await syncRemovals(context, cloud: cloud)
    try await syncFromCloud(context, cloud: cloud)
    try await syncUploads(context, cloud: cloud)
    try context.save()
}

@MainActor
private func syncRemovals(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let ids = try context.fetch(FetchDescriptor<RemovedSavedMovie>()).map(\.movieId)
    for movieId in ids {
        try await cloud.removeMovie(movieId)
        removeDeletionMark(context, movieId: movieId)
        for saved in fetchSavedMovies(context, movieId: movieId) { saved.isInCloud = false }
        try context.save()
    }
}

@MainActor
private func syncFromCloud(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let deviceIds = Set(try context.fetch(FetchDescriptor<SavedMovie>()).map(\.movieId))
    let movies = try await cloud.fetchMovies()
    let cloudIds = Set(movies.map(\.id))
    for saved in try context.fetch(FetchDescriptor<SavedMovie>()) {
        if saved.isInCloud && !cloudIds.contains(saved.movieId) { context.delete(saved) }
    }
    for movie in movies {
        if try isMarkedRemoved(context, movieId: movie.id) { continue }
        if deviceIds.contains(movie.id) && !isMovieSaved(context, movieId: movie.id) {
            markMovieRemoved(context, movieId: movie.id)
            continue
        }
        if needsNewCloudCopy(context, movie) {
            try await cloud.removeMovie(movie.id)
            if !isMovieSaved(context, movieId: movie.id) {
                removeDeletionMark(context, movieId: movie.id)
            }
            continue
        }
        mergeCloudMovie(context, movie)
    }
    try context.save()
}

@MainActor
private func isMarkedRemoved(_ context: ModelContext, movieId: Int) throws -> Bool {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { $0.movieId == movieId })
    return try !context.fetch(descriptor).isEmpty
}

@MainActor
private func needsNewCloudCopy(_ context: ModelContext, _ movie: CloudSavedMovie) -> Bool {
    guard let saved = fetchSavedMovies(context, movieId: movie.id).first else { return false }
    return !saved.isInCloud && saved.savedAt > movie.savedAt
}

@MainActor
private func mergeCloudMovie(_ context: ModelContext, _ movie: CloudSavedMovie) {
    if let saved = fetchSavedMovies(context, movieId: movie.id).first {
        saved.isInCloud = true
    } else {
        context.insert(
            SavedMovie(movie: movieFromCloud(movie), savedAt: movie.savedAt, isInCloud: true))
    }
}

@MainActor
private func syncUploads(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { !$0.isInCloud })
    let movies = try context.fetch(descriptor).map(cloudMovieFromSaved)
    guard !movies.isEmpty else { return }
    let ids = movies.map(\.id)
    try await cloud.uploadMovies(movies)
    for movieId in ids {
        let copies = fetchSavedMovies(context, movieId: movieId)
        if copies.isEmpty {
            markMovieRemoved(context, movieId: movieId)
        } else {
            let uploadedDate = movies.first { $0.id == movieId }?.savedAt
            for saved in copies { saved.isInCloud = saved.savedAt == uploadedDate }
        }
    }
    try context.save()
}

@MainActor
func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId, title: savedMovie.title, overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate, posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage, genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

@MainActor
func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id, title: cloudMovie.title, overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate, posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage, genreIds: cloudMovie.genreIds
    )
}
