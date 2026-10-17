import Testing

@testable import MyNextMovie

@MainActor
struct MovieDetailViewModelTests {
    @Test func startsIdleWithEmptyDetails() {
        let model = MovieDetailViewModel(movieId: 603, loadDetails: { _ in testMovieDetails })
        #expect(model.state == .idle)
        #expect(model.details.credits.cast.isEmpty)
    }

    @Test func loadsDetailsOfItsMovie() async {
        var receivedId = 0
        let model = MovieDetailViewModel(
            movieId: 603,
            loadDetails: { id in
                receivedId = id
                return testMovieDetails
            })
        await model.load()
        #expect(receivedId == 603)
        #expect(model.details.runtime == 136)
        #expect(model.state == .loaded)
    }

    @Test func showsErrorWhenLoadingFails() async {
        let model = MovieDetailViewModel(movieId: 603, loadDetails: { _ in throw NoConnection() })
        await model.load()
        #expect(model.state == .failed)
        #expect(model.errorMessage == "No connection")
    }

    @Test func loadIfNeededLoadsOnlyOnce() async {
        var count = 0
        let model = MovieDetailViewModel(
            movieId: 603,
            loadDetails: { _ in
                count += 1
                return testMovieDetails
            })
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(count == 1)
    }
}
