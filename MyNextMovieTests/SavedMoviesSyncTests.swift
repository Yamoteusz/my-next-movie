import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

@MainActor
struct SavedMoviesSyncTests {
    @Test func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud()
        toggleSavedMovie(container.mainContext, testMovies[0], now: .now)
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(cloud.movies.map(\.id) == [603])
        #expect(fetchSavedMovies(container.mainContext, movieId: 603).first?.isInCloud == true)
    }

    @Test func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud()
        toggleSavedMovie(container.mainContext, testMovies[0], now: .now)
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(cloud.uploadCount == 1)
    }

    @Test func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(
            moviesFromSaved(fetchSavedMovies(container.mainContext, movieId: 603)) == [
                testMovies[0]
            ])
    }

    @Test func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        toggleSavedMovie(container.mainContext, testMovies[1], now: .now)
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(Set(cloud.movies.map(\.id)) == [603, 27205])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SavedMovie>()) == 2)
    }

    @Test func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        toggleSavedMovie(container.mainContext, testMovies[0], now: .now)
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(cloud.movies.isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 0)
    }

    @Test func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        cloud.movies = []
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(!isMovieSaved(container.mainContext, movieId: 603))
    }

    @Test func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        toggleSavedMovie(container.mainContext, testMovies[0], now: .now)
        toggleSavedMovie(container.mainContext, testMovies[1], now: .now)
        cloud.isOffline = true
        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        }
        #expect(cloud.movies.map(\.id) == [603])
        cloud.isOffline = false
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(cloud.movies.map(\.id) == [27205])
    }

    @Test func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        let newDate = Date(timeIntervalSince1970: 500)
        toggleSavedMovie(container.mainContext, testMovies[0], now: newDate)
        toggleSavedMovie(container.mainContext, testMovies[0], now: newDate)
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(cloud.movies.map(\.id) == [603])
        #expect(cloud.movies.first?.savedAt == newDate)
        #expect(fetchSavedMovies(container.mainContext, movieId: 603).first?.savedAt == newDate)
    }

    @Test func deletionDuringUploadLeavesMarkForNextSync() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud()
        let context = container.mainContext
        toggleSavedMovie(context, testMovies[0], now: .now)
        cloud.onUpload = { toggleSavedMovie(context, testMovies[0], now: .now) }
        try await syncSavedMovies(context, cloud: cloud.service())
        #expect(!isMovieSaved(context, movieId: 603))
        #expect(try context.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 1)
        cloud.onUpload = nil
        try await syncSavedMovies(context, cloud: cloud.service())
        #expect(cloud.movies.isEmpty)
    }

    @Test func deletionDuringFetchDoesNotRestoreMovie() async throws {
        let container = try makeTestContainer()
        let cloud = TestCloud(movies: [cloudMovie(0)])
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        cloud.onFetch = { toggleSavedMovie(container.mainContext, testMovies[0], now: .now) }
        try await syncSavedMovies(container.mainContext, cloud: cloud.service())
        #expect(!isMovieSaved(container.mainContext, movieId: 603))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 1)
    }
}

@MainActor
struct CloudSavedMovieTests {
    @Test func encodesColumnNamesInSnakeCase() throws {
        let data = try JSONEncoder().encode(cloudMovie(0))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["release_date", "poster_path", "vote_average", "genre_ids", "saved_at"] {
            #expect(json[key] != nil)
        }
        #expect(json["user_id"] == nil)
    }

    @Test func cloudCopyKeepsEveryMovieField() {
        let saved = SavedMovie(movie: testMovies[0], savedAt: .now)
        #expect(movieFromCloud(cloudMovieFromSaved(saved)) == testMovies[0])
    }
}

@MainActor
private func cloudMovie(_ index: Int) -> CloudSavedMovie {
    return cloudMovieFromSaved(
        SavedMovie(movie: testMovies[index], savedAt: Date(timeIntervalSince1970: 0)))
}

@MainActor
private final class TestCloud {
    var movies: [CloudSavedMovie]
    var isOffline = false
    var uploadCount = 0
    var onUpload: (() -> Void)?
    var onFetch: (() -> Void)?

    init(movies: [CloudSavedMovie] = []) { self.movies = movies }

    func service() -> SavedMoviesCloud {
        return SavedMoviesCloud(
            fetchMovies: {
                if self.isOffline { throw NoConnection() }
                let snapshot = self.movies
                self.onFetch?()
                return snapshot
            },
            uploadMovies: { movies in
                if self.isOffline { throw NoConnection() }
                self.uploadCount += 1
                self.onUpload?()
                self.insertIgnoringDuplicates(movies)
            },
            removeMovie: { id in
                if self.isOffline { throw NoConnection() }
                self.movies.removeAll { $0.id == id }
            }
        )
    }

    private func insertIgnoringDuplicates(_ newMovies: [CloudSavedMovie]) {
        for movie in newMovies {
            if !movies.contains(where: { $0.id == movie.id }) { movies.append(movie) }
        }
    }
}
