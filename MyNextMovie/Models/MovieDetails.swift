import Foundation

nonisolated struct MovieDetails: Decodable {
    var id: Int
    var tagline: String
    var runtime: Int?
    var credits: Credits
    var videos: VideoList
    var releaseDates: ReleaseDateList
    var watchProviders: WatchProviderList
    var recommendations: TMDBMoviePage

    enum CodingKeys: String, CodingKey {
        case id, tagline, runtime, credits, videos, releaseDates, recommendations
        case watchProviders = "watch/providers"
    }
}

nonisolated struct Credits: Decodable {
    var cast: [CastMember]
    var crew: [CrewMember]
}

nonisolated struct CastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
}

nonisolated struct CrewMember: Decodable {
    let id: Int
    let name: String
    let job: String
}

nonisolated struct VideoList: Decodable {
    var results: [Video]
}

nonisolated struct Video: Decodable {
    let key: String
    let site: String
    let type: String
    let official: Bool
}

nonisolated struct ReleaseDateList: Decodable {
    var results: [CountryReleaseDates]
}

nonisolated struct CountryReleaseDates: Decodable {
    let countryCode: String
    let releaseDates: [ReleaseDate]

    enum CodingKeys: String, CodingKey {
        case countryCode = "iso31661"
        case releaseDates
    }
}

nonisolated struct ReleaseDate: Decodable {
    let certification: String
}

nonisolated struct WatchProviderList: Decodable {
    var results: [String: CountryWatchProviders]
}

nonisolated struct CountryWatchProviders: Decodable {
    let link: String
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    var id: Int { return providerId }
}

let noWatchProviders = CountryWatchProviders(link: "", flatrate: nil, rent: nil, buy: nil)
let watchRegionCode = Locale.current.region?.identifier ?? "PL"
let emptyMovieDetails = MovieDetails(
    id: 0, tagline: "", runtime: nil, credits: Credits(cast: [], crew: []),
    videos: VideoList(results: []), releaseDates: ReleaseDateList(results: []),
    watchProviders: WatchProviderList(results: [:]), recommendations: TMDBMoviePage(results: [])
)

func formattedRuntime(_ details: MovieDetails) -> String {
    guard let minutes = details.runtime, minutes > 0 else { return "" }
    if minutes < 60 { return "\(minutes)m" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

func directorNames(_ details: MovieDetails) -> String {
    var seen: Set<Int> = []
    var names: [String] = []
    for person in details.credits.crew {
        if person.job == "Director" && seen.insert(person.id).inserted {
            names.append(person.name)
        }
    }
    return names.joined(separator: ", ")
}

func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    let dates = details.releaseDates.results.filter { $0.countryCode == regionCode }
    return dates.flatMap(\.releaseDates).first { !$0.certification.isEmpty }?.certification ?? ""
}

func trailerKey(_ details: MovieDetails) -> String {
    let trailers = details.videos.results.filter {
        $0.site == "YouTube" && $0.type == "Trailer" && !$0.key.isEmpty
    }
    return (trailers.first { $0.official } ?? trailers.first)?.key ?? ""
}

func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    guard !key.isEmpty else { return nil }
    var address = URLComponents(string: "https://www.youtube.com/watch")
    address?.queryItems = [URLQueryItem(name: "v", value: key)]
    return address?.url
}

func hasTrailer(_ details: MovieDetails) -> Bool { return trailerURL(details) != nil }

func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    return [
        yearAndRating(movie), formattedRuntime(details),
        ageCertification(details, regionCode: regionCode),
    ]
    .filter { !$0.isEmpty }.joined(separator: textSeparator)
}

func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    return details.watchProviders.results[regionCode] ?? noWatchProviders
}

func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    return !(countryProviders.flatrate ?? []).isEmpty || !(countryProviders.rent ?? []).isEmpty
        || !(countryProviders.buy ?? []).isEmpty
}

func profileURL(_ castMember: CastMember) -> URL? {
    guard let path = castMember.profilePath, !path.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w185" + path)
}

func logoURL(_ provider: WatchProvider) -> URL? {
    guard let path = provider.logoPath, !path.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w92" + path)
}
