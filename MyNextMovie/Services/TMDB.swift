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

private func requireTMDBAPIKey() throws -> String {
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
    return try decodeTMDBMovies(await fetchTMDBData(tmdbPopularURL(apiKey: requireTMDBAPIKey())))
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let address = try tmdbSearchURL(query: query, genreId: genreId, apiKey: requireTMDBAPIKey())
    let movies = try decodeTMDBMovies(await fetchTMDBData(address))
    return filterMovies(movies, query: "", genreId: genreId)
}

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let address = try tmdbMovieDetailsURL(movieId: movieId, apiKey: requireTMDBAPIKey())
    return try decodeTMDBMovieDetails(await fetchTMDBData(address))
}

func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let data = try await fetchWithCacheFallback(cache, key: "popular") {
        return try await fetchTMDBData(tmdbPopularURL(apiKey: requireTMDBAPIKey()))
    }
    return try decodeTMDBMovies(data)
}

func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let data = try await fetchWithCacheFallback(cache, key: "movie/" + String(movieId)) {
        return try await fetchTMDBData(
            tmdbMovieDetailsURL(movieId: movieId, apiKey: requireTMDBAPIKey()))
    }
    return try decodeTMDBMovieDetails(data)
}

nonisolated struct TMDBRequest: Equatable, Sendable {
    let path: String
    let parameters: [URLQueryItem]
}

typealias TMDBFetch = @MainActor (_ request: TMDBRequest) async throws -> Data

let tmdbPathDiscoverMovies = "/3/discover/movie"
let tmdbPathSearchPeople = "/3/search/person"
let tmdbPathSearchKeywords = "/3/search/keyword"
nonisolated let noTMDBId = 0

@MainActor
func fetchTMDBRequest(_ request: TMDBRequest) async throws -> Data {
    let apiKey = try requireTMDBAPIKey()
    let address = tmdbURL(path: request.path, parameters: request.parameters, apiKey: apiKey)
    return try await fetchTMDBData(address)
}

func tmdbDiscoverRequest(_ filters: MovieFilters, personIds: [Int], keywordIds: [Int])
    -> TMDBRequest
{
    var parameters: [URLQueryItem] = []
    if !filters.genreIds.isEmpty {
        parameters.append(
            URLQueryItem(
                name: "with_genres", value: filters.genreIds.map(String.init).joined(separator: "|")
            ))
    }
    if !personIds.isEmpty {
        parameters.append(
            URLQueryItem(
                name: "with_people", value: personIds.map(String.init).joined(separator: ",")))
    }
    if !keywordIds.isEmpty {
        parameters.append(
            URLQueryItem(
                name: "with_keywords", value: keywordIds.map(String.init).joined(separator: "|")))
    }
    if filters.fromYear != noYear {
        parameters.append(
            URLQueryItem(name: "primary_release_date.gte", value: "\(filters.fromYear)-01-01"))
    }
    if filters.toYear != noYear {
        parameters.append(
            URLQueryItem(name: "primary_release_date.lte", value: "\(filters.toYear)-12-31"))
    }
    return TMDBRequest(path: tmdbPathDiscoverMovies, parameters: parameters)
}

func tmdbNameSearchRequest(path: String, name: String) -> TMDBRequest {
    return TMDBRequest(path: path, parameters: [URLQueryItem(name: queryParameter, value: name)])
}

nonisolated private struct TMDBIDPage: Decodable {
    let results: [TMDBIDResult]
}

nonisolated private struct TMDBIDResult: Decodable {
    let id: Int
}

nonisolated func decodeFirstTMDBId(_ data: Data) throws -> Int {
    return try JSONDecoder().decode(TMDBIDPage.self, from: data).results.first?.id ?? noTMDBId
}

@MainActor
func searchTMDBMoviesByFilters(_ filters: MovieFilters) async throws -> [Movie] {
    return try await searchMoviesByFilters(filters, fetch: fetchTMDBRequest)
}

@MainActor
func searchMoviesByFilters(_ filters: MovieFilters, fetch: @escaping TMDBFetch) async throws
    -> [Movie]
{
    let filters = validatedFilters(filters, currentYear: yearOfToday())
    guard hasAnyFilter(filters) else { return [] }
    if !filters.title.isEmpty {
        let request = tmdbNameSearchRequest(path: searchPath, name: filters.title)
        return try moviesMatchingFilters(decodeTMDBMovies(await fetch(request)), filters)
    }
    async let people = lookupTMDBIds(filters.people, path: tmdbPathSearchPeople, fetch: fetch)
    async let keywords = lookupTMDBIds(filters.keywords, path: tmdbPathSearchKeywords, fetch: fetch)
    let (personIds, keywordIds) = try await (people, keywords)
    guard !personIds.contains(noTMDBId) else { return [] }
    let request = tmdbDiscoverRequest(
        filters, personIds: personIds, keywordIds: keywordIds.filter { $0 != noTMDBId })
    guard !request.parameters.isEmpty else { return [] }
    return try decodeTMDBMovies(await fetch(request))
}

@MainActor
private func lookupTMDBIds(_ names: [String], path: String, fetch: @escaping TMDBFetch) async throws
    -> [Int]
{
    return try await withThrowingTaskGroup(of: (Int, Int).self) { group in
        for (index, name) in names.enumerated() {
            let request = tmdbNameSearchRequest(path: path, name: name)
            group.addTask { return (index, try decodeFirstTMDBId(await fetch(request))) }
        }
        var ids = Array(repeating: noTMDBId, count: names.count)
        for try await (index, id) in group { ids[index] = id }
        return ids
    }
}
