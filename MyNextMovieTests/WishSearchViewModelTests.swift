import Foundation
import Testing

@testable import MyNextMovie

@MainActor
struct WishSearchViewModelTests {
    @Test func searchesWithTheFiltersOfTheModel() async {
        let filters = makeMovieFilters(genres: [35], from: 1990, to: 1999, people: ["Keanu Reeves"])
        var receivedWish = ""
        var receivedFilters: MovieFilters?
        let model = WishSearchViewModel(
            parseWish: { wish in
                receivedWish = wish
                return filters
            },
            searchByFilters: {
                receivedFilters = $0
                return testMovies
            },
            searchByText: { _, _ in
                Issue.record("Unexpected text search")
                return []
            }, currentYear: 2026
        )
        model.wish = " something light with Keanu "
        await model.search()
        #expect(receivedWish == "something light with Keanu")
        #expect(receivedFilters == filters)
        #expect(model.filters == filters)
        #expect(model.movies == testMovies)
        #expect(model.state == .loaded)
        #expect(!model.isPlainSearch)
    }

    @Test func checksTheModelAnswerBeforeSearching() async {
        var received: MovieFilters?
        let model = WishSearchViewModel(
            parseWish: { _ in makeMovieFilters(genres: [35, 1, 35], from: 1999, to: 1990) },
            searchByFilters: {
                received = $0
                return []
            }, searchByText: { _, _ in [] }, currentYear: 2026
        )
        model.wish = "a comedy from the 90s"
        await model.search()
        #expect(received == makeMovieFilters(genres: [35], from: 1990, to: 1999))
    }

    @Test func fallsBackToTextSearchWhenTheModelFails() async {
        var query = ""
        var genre = -1
        let model = WishSearchViewModel(
            parseWish: { _ in throw NoConnection() },
            searchByFilters: { _ in
                Issue.record("Unexpected filtered search")
                return []
            },
            searchByText: {
                query = $0
                genre = $1
                return testMovies
            }, currentYear: 2026
        )
        model.wish = "  matrix \n"
        await model.search()
        #expect(query == "matrix")
        #expect(genre == noGenreId)
        #expect(model.plainSearchReason.contains("No connection"))
        #expect(model.isPlainSearch)
        #expect(model.movies == testMovies)
        #expect(model.state == .loaded)
    }

    @Test func fallsBackToTextSearchWithoutFilters() async {
        var calls = 0
        let model = WishSearchViewModel(
            parseWish: { _ in noMovieFilters }, searchByFilters: { _ in [] },
            searchByText: { _, _ in
                calls += 1
                return []
            }, currentYear: 2026
        )
        model.wish = "something"
        await model.search()
        #expect(calls == 1)
        #expect(model.isPlainSearch)
        #expect(model.filters == noMovieFilters)
        #expect(model.state == .loaded)
    }

    @Test func showsErrorWhenTheMovieSearchFails() async {
        let model = WishSearchViewModel(
            parseWish: { _ in makeMovieFilters(genres: [35]) },
            searchByFilters: { _ in throw NoConnection() }, searchByText: { _, _ in [] },
            currentYear: 2026
        )
        model.wish = "comedy"
        await model.search()
        #expect(model.state == .failed)
        #expect(model.errorMessage == "No connection")
    }

    @Test func emptyWishDoesNothing() async {
        var calls = 0
        let model = WishSearchViewModel(
            parseWish: { _ in
                calls += 1
                return noMovieFilters
            },
            searchByFilters: { _ in [] }, searchByText: { _, _ in [] }, currentYear: 2026
        )
        model.wish = " \n\t "
        #expect(!model.canSearch)
        await model.search()
        #expect(calls == 0)
        #expect(model.state == .idle)
    }

    @Test func nextSearchForgetsThePlainSearchReason() async {
        let parser = TestWishParser()
        let model = WishSearchViewModel(
            parseWish: parser.parse, searchByFilters: { _ in [] }, searchByText: { _, _ in [] },
            currentYear: 2026
        )
        model.wish = "comedy"
        await model.search()
        #expect(model.isPlainSearch)
        parser.shouldFail = false
        await model.search()
        #expect(!model.isPlainSearch)
        #expect(model.plainSearchReason.isEmpty)
        #expect(model.errorMessage.isEmpty)
    }

    @Test func wishLimitCountsUnicodeScalars() async {
        var text = ""
        let model = WishSearchViewModel(
            parseWish: {
                text = $0
                return noMovieFilters
            }, searchByFilters: { _ in [] },
            searchByText: { _, _ in [] }, currentYear: 2026
        )
        model.wish = String(repeating: "👨‍👩‍👧‍👦", count: 100)
        await model.search()
        #expect(text.unicodeScalars.count == 200)
    }

    @Test func cancellationDoesNotStartPlainSearch() async {
        var calls = 0
        let model = WishSearchViewModel(
            parseWish: { _ in throw CancellationError() }, searchByFilters: { _ in [] },
            searchByText: { _, _ in
                calls += 1
                return []
            }, currentYear: 2026
        )
        model.wish = "comedy"
        await model.search()
        #expect(model.state == .idle)
        #expect(calls == 0)
        #expect(model.plainSearchReason.isEmpty)
    }
}

@MainActor
private final class TestWishParser {
    var shouldFail = true
    func parse(_ wish: String) async throws -> MovieFilters {
        if shouldFail { throw NoConnection() }
        return makeMovieFilters(genres: [35])
    }
}
