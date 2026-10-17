import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

@MainActor
struct SavedMovieTests {
    @Test func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        toggleSavedMovie(context, testMovies[0], now: .now)
        #expect(isMovieSaved(context, movieId: 603))
        toggleSavedMovie(context, testMovies[0], now: .now)
        #expect(!isMovieSaved(context, movieId: 603))
    }

    @Test func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        toggleSavedMovie(container.mainContext, testMovies[0], now: .now)
        #expect(
            moviesFromSaved(fetchSavedMovies(container.mainContext, movieId: 603)) == [
                testMovies[0]
            ])
    }

    @Test func removingMovieTheAccountHasLeavesAMark() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        context.insert(SavedMovie(movie: testMovies[0], savedAt: .now, isInCloud: true))
        toggleSavedMovie(context, testMovies[0], now: .now)
        #expect(try context.fetch(FetchDescriptor<RemovedSavedMovie>()).map(\.movieId) == [603])
        #expect(!isMovieSaved(context, movieId: 603))
    }

    @Test func removingMovieOnlyOnDeviceLeavesNoMark() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        toggleSavedMovie(context, testMovies[0], now: .now)
        toggleSavedMovie(context, testMovies[0], now: .now)
        #expect(try context.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 0)
    }

    @Test func clearRemovesMoviesAndMarks() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        toggleSavedMovie(context, testMovies[0], now: .now)
        context.insert(RemovedSavedMovie(movieId: 1))
        clearSavedMovies(context)
        #expect(try context.fetchCount(FetchDescriptor<SavedMovie>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 0)
    }
}

@MainActor
struct SearchHistoryTests {
    @Test func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        recordSearch(container.mainContext, query: "matrix", now: time(1))
        recordSearch(container.mainContext, query: "alien", now: time(2))
        #expect(recentSearches(container.mainContext).map(\.query) == ["alien", "matrix"])
    }

    @Test func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        recordSearch(container.mainContext, query: "matrix", now: time(1))
        recordSearch(container.mainContext, query: "alien", now: time(2))
        recordSearch(container.mainContext, query: "matrix", now: time(3))
        #expect(recentSearches(container.mainContext).map(\.query) == ["matrix", "alien"])
    }

    @Test func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        for query in ["", "   ", "  dune  "] {
            recordSearch(container.mainContext, query: query, now: time(1))
        }
        #expect(recentSearches(container.mainContext).map(\.query) == ["dune"])
    }

    @Test func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        for index in 1...13 {
            recordSearch(container.mainContext, query: "movie \(index)", now: time(index))
        }
        #expect(recentSearches(container.mainContext).count == 10)
        #expect(recentSearches(container.mainContext).first?.query == "movie 13")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 10)
    }

    @Test func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        recordSearch(container.mainContext, query: "matrix", now: time(1))
        clearSearchHistory(container.mainContext)
        #expect(recentSearches(container.mainContext).isEmpty)
    }

    private func time(_ minute: Int) -> Date {
        return Date(timeIntervalSince1970: Double(60 * minute))
    }
}

@MainActor
struct ResponseCacheTests {
    @Test func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()
        #expect(cachedResponseData(container.mainContext, key: "missing").isEmpty)
    }

    @Test func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        storeCachedResponse(container.mainContext, key: "popular", data: Data([1]), now: .now)
        storeCachedResponse(container.mainContext, key: "popular", data: Data([2]), now: .now)
        #expect(cachedResponseData(container.mainContext, key: "popular") == Data([2]))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<CachedResponse>()) == 1)
    }

    @Test func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let data = try await fetchWithCacheFallback(container.mainContext, key: "popular") {
            Data([3])
        }
        #expect(data == Data([3]))
        #expect(cachedResponseData(container.mainContext, key: "popular") == data)
    }

    @Test func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        storeCachedResponse(container.mainContext, key: "popular", data: Data([4]), now: .now)
        let data = try await fetchWithCacheFallback(container.mainContext, key: "popular") {
            throw NoConnection()
        }
        #expect(data == Data([4]))
    }

    @Test func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        await #expect(throws: NoConnection.self) {
            try await fetchWithCacheFallback(container.mainContext, key: "popular") {
                throw NoConnection()
            }
        }
    }
}
