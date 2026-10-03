import Testing

@testable import MyNextMovie

@MainActor
struct FilterMoviesTests {
    @Test func emptyQueryAndNoGenreReturnsEveryMovie() {
        #expect(filterMovies(sampleMovies, query: "", genreId: noGenreId) == sampleMovies)
    }

    @Test func matchesTitleIgnoringCase() {
        let foundMovies = filterMovies(sampleMovies, query: "matrix", genreId: noGenreId)
        #expect(titlesOf(foundMovies) == ["The Matrix"])
    }

    @Test func matchesKeywordInOverview() {
        let foundMovies = filterMovies(sampleMovies, query: "wormhole", genreId: noGenreId)
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
        let foundMovies = filterMovies(sampleMovies, query: "", genreId: genreIdAnimation)
        #expect(titlesOf(foundMovies) == ["Spirited Away"])
    }

    @Test
    func combinesQueryAndGenre() {
        #expect(filterMovies(sampleMovies, query: "matrix", genreId: genreIdAnimation).isEmpty)
        #expect(
            titlesOf(filterMovies(sampleMovies, query: "matrix", genreId: genreIdAction)) == [
                "The Matrix"
            ])
    }

    @Test func trimsSpacesAroundQuery() {
        let foundMovies = filterMovies(sampleMovies, query: "  inception ", genreId: noGenreId)
        #expect(titlesOf(foundMovies) == ["Inception"])
    }
}

@MainActor
struct SearchViewModelTests {
    @Test func staysIdleWithoutQueryOrGenre() async {
        var searchCount = 0
        let viewModel = SearchViewModel(searchMovies: { _, _ in
            searchCount += 1
            return sampleMovies
        })
        viewModel.query = "   "

        await viewModel.search()

        #expect(viewModel.state == .idle)
        #expect(searchCount == 0)
    }

    @Test func searchesByGenreWithoutQuery() async {
        let viewModel = SearchViewModel(searchMovies: searchSampleMovies)
        viewModel.selectedGenreId = genreIdAnimation

        await viewModel.search()

        #expect(viewModel.state == .loaded)
        #expect(titlesOf(viewModel.movies) == ["Spirited Away"])
    }

    @Test func clearingSearchReturnsToIdle() async {
        let viewModel = SearchViewModel(searchMovies: searchSampleMovies)
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
