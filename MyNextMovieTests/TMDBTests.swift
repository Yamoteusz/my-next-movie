import Foundation
import Testing

@testable import MyNextMovie

@MainActor
struct TMDBTests {
    @Test func decodesSnakeCaseKeys() throws {
        let movie = try #require(decodeTMDBMovies(moviePageJSON).first)
        #expect(movie.releaseDate == "1999-03-31")
        #expect(movie.posterPath == "/matrix.jpg")
        #expect(movie.voteAverage == 8.2)
        #expect(movie.genreIds == [28, 878])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let json = String(decoding: moviePageJSON, as: UTF8.self).replacingOccurrences(
            of: "\"/matrix.jpg\"", with: "null")
        #expect(try decodeTMDBMovies(Data(json.utf8)).first?.posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(Data("{\"status_code\":7}".utf8))
        }
    }

    @Test func popularURLHasAPIKey() {
        #expect(
            tmdbPopularURL(apiKey: "test-key")?.absoluteString
                == "https://api.themoviedb.org/3/movie/popular?api_key=test-key")
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let address = try #require(
            tmdbSearchURL(query: " matrix ", genreId: genreIdAction, apiKey: "test"))
        #expect(address.path() == "/3/search/movie")
        #expect(queryItems(address)["query"] == "matrix")
        #expect(queryItems(address)["with_genres"] == nil)
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let address = try #require(
            tmdbSearchURL(query: "", genreId: genreIdAnimation, apiKey: "test"))
        #expect(address.path() == "/3/discover/movie")
        #expect(queryItems(address)["with_genres"] == "16")
    }

    @Test func searchTextIsPercentEncoded() throws {
        let address = try #require(
            tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: "test"))
        #expect(address.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let address = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: "test"))
        #expect(address.path() == "/3/movie/603")
        #expect(
            queryItems(address)["append_to_response"]
                == "credits,videos,release_dates,watch/providers,recommendations")
    }

    @Test func okResponsePasses() throws { try checkTMDBResponse(response(200)) }

    @Test func unauthorizedResponseMentionsAPIKey() throws {
        let error = #expect(throws: TMDBError.self) { try checkTMDBResponse(response(401)) }
        #expect(error?.message.contains("API key") == true)
    }

    @Test func otherErrorResponseShowsStatus() throws {
        let error = #expect(throws: TMDBError.self) { try checkTMDBResponse(response(404)) }
        #expect(error?.message.contains("404") == true)
    }

    private func response(_ status: Int) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        return try #require(
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    }

    private func queryItems(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}

private let moviePageJSON = Data(
    """
    {"results":[{"id":603,"title":"The Matrix","overview":"A hacker learns the truth.",
    "release_date":"1999-03-31","poster_path":"/matrix.jpg","vote_average":8.2,"genre_ids":[28,878]}]}
    """.utf8)
