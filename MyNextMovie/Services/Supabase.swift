import Foundation
import Supabase

private let savedMoviesTable = "saved_movies"
private let movieIdColumn = "id"
private let savedAtColumn = "saved_at"
private let savedMovieConflictKey = "user_id,id"
let minimumPasswordLength = 6
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

struct SupabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}

let supabaseFunctionMovieFilters = "movie-filters"

nonisolated struct MovieWishRequest: Encodable {
    let wish: String
}

nonisolated private struct FunctionErrorAnswer: Decodable {
    let message: String
}

func functionErrorMessage(statusCode: Int, data: Data) -> String {
    if let answer = try? JSONDecoder().decode(FunctionErrorAnswer.self, from: data) {
        let message = answer.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty { return message }
    }
    return "AI search failed (HTTP \(statusCode))."
}

func parseWishWithAI(_ wish: String) async throws -> MovieFilters {
    let client = try requireSupabaseClient()
    let options = FunctionInvokeOptions(body: MovieWishRequest(wish: limitedMovieWish(wish)))
    do {
        return try await client.functions.invoke(supabaseFunctionMovieFilters, options: options)
    } catch FunctionsError.httpError(let status, let data) {
        throw SupabaseError(message: functionErrorMessage(statusCode: status, data: data))
    }
}

private var supabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let supabaseClient { return supabaseClient }
    let key = supabaseAnonKey().trimmingCharacters(in: .whitespacesAndNewlines)
    guard let address = URL(string: supabaseURL()), address.scheme == "https",
        let host = address.host, !host.isEmpty, host != "your-project.supabase.co",
        !key.isEmpty, key != "your_anon_key"
    else {
        throw SupabaseError(message: "Missing Supabase keys. Add them to Config/Secrets.xcconfig.")
    }
    let client = SupabaseClient(supabaseURL: address, supabaseKey: key)
    supabaseClient = client
    return client
}

func supabaseSignedInEmail() -> String {
    return (try? requireSupabaseClient().auth.currentUser?.email) ?? ""
}

func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? ""
}

func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    return response.session?.user.email ?? ""
}

func signOutOfSupabase() async throws {
    let client = try requireSupabaseClient()
    try? await client.auth.signOut(scope: .local)
}

let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail, signIn: signInToSupabase,
    signUp: signUpToSupabase, signOut: signOutOfSupabase
)

nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}

func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    return try await client.from(savedMoviesTable).select()
        .order(savedAtColumn, ascending: false).execute().value
}

func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    guard !cloudMovies.isEmpty else { return }
    let client = try requireSupabaseClient()
    try await client.from(savedMoviesTable)
        .upsert(
            cloudMovies, onConflict: savedMovieConflictKey, returning: .minimal,
            ignoreDuplicates: true
        )
        .execute()
}

func removeCloudSavedMovie(movieId: Int) async throws {
    let client = try requireSupabaseClient()
    try await client.from(savedMoviesTable).delete(returning: .minimal)
        .eq(movieIdColumn, value: movieId).execute()
}

let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies, uploadMovies: uploadCloudSavedMovies,
    removeMovie: removeCloudSavedMovie
)
