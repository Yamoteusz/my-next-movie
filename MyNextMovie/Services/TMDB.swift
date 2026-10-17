import Foundation
import SwiftData

private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"
private let popularPath = "/3/movie/popular"
private let searchPath = "/3/search/movie"
private let discoverPath = "/3/discover/movie"
private let moviePath = "/3/movie/"
private let apiKeyParameter = "api_key"
private let queryParameter = "query"
private let genresParameter = "with_genres"
private let appendParameter = "append_to_response"
let tmdbDetailsParts = "credits,videos,release_dates,watch/providers,recommendations"
let httpStatusOK = 200
let httpStatusUnauthorized = 401

nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

struct TMDBError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}

func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = tmdbScheme
    components.host = tmdbHost
    components.path = path
    components.queryItems = [URLQueryItem(name: apiKeyParameter, value: apiKey)] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: popularPath, parameters: [], apiKey: apiKey)
}

func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
        return tmdbURL(
            path: searchPath, parameters: [URLQueryItem(name: queryParameter, value: text)],
            apiKey: apiKey)
    }
    let parameters =
        genreId == noGenreId ? [] : [URLQueryItem(name: genresParameter, value: String(genreId))]
    return tmdbURL(path: discoverPath, parameters: parameters, apiKey: apiKey)
}

func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    return tmdbURL(
        path: moviePath + String(movieId),
        parameters: [URLQueryItem(name: appendParameter, value: tmdbDetailsParts)], apiKey: apiKey
    )
}

private func tmdbDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    return try tmdbDecoder().decode(TMDBMoviePage.self, from: data).results
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    return try tmdbDecoder().decode(MovieDetails.self, from: data)
}

func checkTMDBResponse(_ response: URLResponse) throws {
    guard let response = response as? HTTPURLResponse else {
        throw TMDBError(message: "Invalid TMDB response.")
    }
    if response.statusCode == httpStatusUnauthorized {
        throw TMDBError(message: "Invalid TMDB API key. Check Config/Secrets.xcconfig.")
    }
    if response.statusCode != httpStatusOK {
        throw TMDBError(message: "TMDB request failed (HTTP \(response.statusCode)).")
    }
}

private func requireTMDBKey() throws -> String {
    let key = tmdbAPIKey().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty && key != "your_tmdb_api_key" else {
        throw TMDBError(message: "Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    return key
}

private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let address else { throw TMDBError(message: "Invalid TMDB address.") }
    let (data, response) = try await URLSession.shared.data(from: address)
    try checkTMDBResponse(response)
    return data
}

func fetchPopularMovies() async throws -> [Movie] {
    return try decodeTMDBMovies(await fetchTMDBData(tmdbPopularURL(apiKey: requireTMDBKey())))
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let address = try tmdbSearchURL(query: query, genreId: genreId, apiKey: requireTMDBKey())
    let movies = try decodeTMDBMovies(await fetchTMDBData(address))
    return filterMovies(movies, query: "", genreId: genreId)
}

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let address = try tmdbMovieDetailsURL(movieId: movieId, apiKey: requireTMDBKey())
    return try decodeTMDBMovieDetails(await fetchTMDBData(address))
}

func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let data = try await fetchWithCacheFallback(cache, key: "popular") {
        return try await fetchTMDBData(tmdbPopularURL(apiKey: requireTMDBKey()))
    }
    return try decodeTMDBMovies(data)
}

func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let data = try await fetchWithCacheFallback(cache, key: "movie/" + String(movieId)) {
        return try await fetchTMDBData(
            tmdbMovieDetailsURL(movieId: movieId, apiKey: requireTMDBKey()))
    }
    return try decodeTMDBMovieDetails(data)
}
