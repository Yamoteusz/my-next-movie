import Testing

@testable import MyNextMovie

@MainActor
struct FilterMoviesTests {
    @Test func emptyQueryAndNoGenreReturnsEveryMovie() {
        #expect(filterMovies(testMovies, query: "", genreId: noGenreId) == testMovies)
    }

    @Test func matchesTitleIgnoringCase() {
        let foundMovies = filterMovies(testMovies, query: "matrix", genreId: noGenreId)
        #expect(titlesOf(foundMovies) == ["The Matrix"])
    }

    @Test func matchesKeywordInOverview() {
        let foundMovies = filterMovies(testMovies, query: "wormhole", genreId: noGenreId)
        #expect(titlesOf(foundMovies) == ["Interstellar"])
    }

    @Test
    func ignoresDiacritics() {
        let movie = Movie(
            id: 1, title: "Amélie", overview: "", releaseDate: "", posterPath: nil,
            voteAverage: 0, genreIds: []
        )
        #expect(filterMovies([movie], query: "amelie", genreId: noGenreId) == [movie])
    }

    @Test func filtersByGenre() {
        let foundMovies = filterMovies(testMovies, query: "", genreId: genreIdAnimation)
        #expect(titlesOf(foundMovies) == ["Spirited Away"])
    }

    @Test
    func combinesQueryAndGenre() {
        #expect(filterMovies(testMovies, query: "matrix", genreId: genreIdAnimation).isEmpty)
        #expect(
            titlesOf(filterMovies(testMovies, query: "matrix", genreId: genreIdAction)) == [
                "The Matrix"
            ])
    }

    @Test func trimsSpacesAroundQuery() {
        let foundMovies = filterMovies(testMovies, query: "  inception ", genreId: noGenreId)
        #expect(titlesOf(foundMovies) == ["Inception"])
    }
}

@MainActor
struct SearchViewModelTests {
    @Test func staysIdleWithoutQueryOrGenre() async {
        var searchCount = 0
        let viewModel = SearchViewModel(searchMovies: { _, _ in
            searchCount += 1
            return testMovies
        })
        viewModel.query = "   "

        await viewModel.search()

        #expect(viewModel.state == .idle)
        #expect(searchCount == 0)
    }

    @Test func searchesByGenreWithoutQuery() async {
        let viewModel = SearchViewModel(searchMovies: filterTestMovies)
        viewModel.selectedGenreId = genreIdAnimation

        await viewModel.search()

        #expect(viewModel.state == .loaded)
        #expect(titlesOf(viewModel.movies) == ["Spirited Away"])
    }

    @Test func clearingSearchReturnsToIdle() async {
        let viewModel = SearchViewModel(searchMovies: filterTestMovies)
        viewModel.query = "matrix"
        await viewModel.search()
        #expect(titlesOf(viewModel.movies) == ["The Matrix"])

        viewModel.query = ""
        await viewModel.search()

        #expect(viewModel.state == .idle)
        #expect(viewModel.movies.isEmpty)
    }

    @Test
    func passesTrimmedQueryAndGenreToSearch() async {
        var receivedQuery = ""
        var receivedGenreId = noGenreId
        let viewModel = SearchViewModel(searchMovies: { query, genreId in
            receivedQuery = query
            receivedGenreId = genreId
            return []
        })
        viewModel.query = " matrix "
        viewModel.selectedGenreId = genreIdAction

        await viewModel.search()

        #expect(receivedQuery == "matrix")
        #expect(receivedGenreId == genreIdAction)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.movies.isEmpty)
    }

    @Test func showsErrorWhenSearchFails() async {
        let viewModel = SearchViewModel(searchMovies: { _, _ in throw NoConnection() })
        viewModel.query = "matrix"

        await viewModel.search()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
    }

    @Test func olderSearchDoesNotReplaceNewerResults() async throws {
        var finishFirst: CheckedContinuation<[Movie], Never>?
        let viewModel = SearchViewModel(searchMovies: { query, _ in
            if query == "matrix" {
                return await withCheckedContinuation { finishFirst = $0 }
            }
            return [testMovies[1]]
        })
        viewModel.query = "matrix"
        let first = Task { await viewModel.search() }
        while finishFirst == nil { await Task.yield() }
        viewModel.query = "inception"
        await viewModel.search()
        finishFirst?.resume(returning: [testMovies[0]])
        await first.value
        #expect(viewModel.movies == [testMovies[1]])
        #expect(viewModel.state == .loaded)
    }

    @Test
    func togglingSelectedGenreClearsIt() {
        let viewModel = SearchViewModel(searchMovies: { _, _ in [] })
        viewModel.toggleGenre(genreIdAction)
        #expect(viewModel.selectedGenreId == genreIdAction)
        viewModel.toggleGenre(genreIdAction)
        #expect(viewModel.selectedGenreId == noGenreId)
    }
}

private func titlesOf(_ movies: [Movie]) -> [String] {
    var movieTitles: [String] = []
    for movie in movies {
        movieTitles.append(movie.title)
    }
    return movieTitles
}
