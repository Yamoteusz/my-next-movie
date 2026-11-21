import Foundation
import Testing

@testable import MyNextMovie

@MainActor
struct FilteredSearchTests {
    @Test func namesBecomeIdsInOneDiscoverRequest() async throws {
        let tmdb = TestTMDB()
        let filters = makeMovieFilters(
            genres: [35], people: ["Keanu Reeves", "Sandra Bullock"], keywords: ["heist"])
        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)
        let discover = try #require(tmdb.requests.first { $0.path == tmdbPathDiscoverMovies })
        #expect(parameter(discover, "with_people") == "6384,18277")
        #expect(parameter(discover, "with_keywords") == "100")
        #expect(tmdb.requests.filter { $0.path == tmdbPathDiscoverMovies }.count == 1)
        #expect(movies == testMovies)
    }

    @Test func looksUpEveryNameAtOnce() async throws {
        let tmdb = TestTMDB()
        tmdb.waitForAllNames = true
        let filters = makeMovieFilters(
            people: ["Keanu Reeves", "Sandra Bullock"], keywords: ["heist", "ghost"])
        let search = Task { try await searchMoviesByFilters(filters, fetch: tmdb.fetch) }
        for _ in 0..<1000 {
            if tmdb.waiting.count == 4 { break }
            await Task.yield()
        }
        let concurrentCount = tmdb.waiting.count
        tmdb.releaseNames()
        _ = try await search.value
        #expect(concurrentCount == 4)
    }

    @Test func unknownPersonFindsNothing() async throws {
        let tmdb = TestTMDB()
        let movies = try await searchMoviesByFilters(
            makeMovieFilters(genres: [35], people: ["Unknown Person"]), fetch: tmdb.fetch)
        #expect(movies.isEmpty)
        #expect(!tmdb.requests.contains { $0.path == tmdbPathDiscoverMovies })
    }

    @Test func onlyUnknownKeywordsFindNothing() async throws {
        let tmdb = TestTMDB()
        let movies = try await searchMoviesByFilters(
            makeMovieFilters(keywords: ["unknown"]), fetch: tmdb.fetch)
        #expect(movies.isEmpty)
        #expect(!tmdb.requests.contains { $0.path == tmdbPathDiscoverMovies })
    }

    @Test func unknownKeywordNextToGenreStillSearches() async throws {
        let tmdb = TestTMDB()
        _ = try await searchMoviesByFilters(
            makeMovieFilters(genres: [35], keywords: ["unknown"]), fetch: tmdb.fetch)
        let request = try #require(tmdb.requests.first { $0.path == tmdbPathDiscoverMovies })
        #expect(parameter(request, "with_genres") == "35")
        #expect(parameter(request, "with_keywords") == nil)
    }

    @Test func titleSearchKeepsYearsAndGenres() async throws {
        let tmdb = TestTMDB()
        let movies = try await searchMoviesByFilters(
            makeMovieFilters(genres: [28], from: 1999, to: 1999, title: "Matrix"), fetch: tmdb.fetch
        )
        #expect(movies.map(\.title) == ["The Matrix"])
        #expect(tmdb.requests.count == 1)
        #expect(tmdb.requests.first?.path == "/3/search/movie")
        #expect(tmdb.requests.first.flatMap { parameter($0, "query") } == "Matrix")
    }

    @Test func emptyFiltersDoNotFetchPopularMovies() async throws {
        let tmdb = TestTMDB()
        #expect(try await searchMoviesByFilters(noMovieFilters, fetch: tmdb.fetch).isEmpty)
        #expect(tmdb.requests.isEmpty)
    }
}

@MainActor
struct MoviesMatchingFiltersTests {
    @Test func withoutGenresAndYearsAllMatch() {
        #expect(moviesMatchingFilters(testMovies, noMovieFilters) == testMovies)
    }

    @Test func anyOfTheGenresMatches() {
        let movies = moviesMatchingFilters(
            testMovies, makeMovieFilters(genres: [genreIdAnimation, genreIdRomance]))
        #expect(movies.map(\.title) == ["Spirited Away", "Titanic"])
    }

    @Test func movieWithoutYearDoesNotMatchYears() {
        #expect(moviesMatchingFilters([makeMovie()], makeMovieFilters(from: 1990)).isEmpty)
    }

    @Test func yearsIncludeBothEnds() {
        let movies = moviesMatchingFilters(testMovies, makeMovieFilters(from: 1997, to: 1999))
        #expect(movies.map(\.title) == ["The Matrix", "Titanic"])
    }
}

@MainActor
private final class TestTMDB {
    var requests: [TMDBRequest] = []
    var waitForAllNames = false
    var waiting: [CheckedContinuation<Void, Never>] = []

    func fetch(_ request: TMDBRequest) async throws -> Data {
        requests.append(request)
        if request.path == tmdbPathSearchPeople || request.path == tmdbPathSearchKeywords {
            if waitForAllNames { await withCheckedContinuation { waiting.append($0) } }
            let ids = ["Keanu Reeves": 6384, "Sandra Bullock": 18277, "heist": 100, "ghost": 200]
            let name = parameter(request, "query") ?? ""
            if let id = ids[name] { return Data("{\"results\":[{\"id\":\(id)}]}".utf8) }
            return Data("{\"results\":[]}".utf8)
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(MoviePageForTest(results: testMovies))
    }

    func releaseNames() {
        waitForAllNames = false
        let continuations = waiting
        waiting = []
        for continuation in continuations { continuation.resume() }
    }
}

nonisolated private struct MoviePageForTest: Encodable {
    let results: [Movie]
}
