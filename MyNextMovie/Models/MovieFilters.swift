import Foundation

nonisolated struct MovieFilters: Codable, Equatable, Sendable {
    let genreIds: [Int]
    let fromYear: Int
    let toYear: Int
    let people: [String]
    let keywords: [String]
    let title: String
}

let noYear = 0
let earliestMovieYear = 1880
let yearsAheadOfToday = 5
let maxFilterValues = 3
let maxWishLength = 200
let noMovieFilters = MovieFilters(
    genreIds: [], fromYear: noYear, toYear: noYear, people: [], keywords: [], title: ""
)

func yearOfToday() -> Int { return Calendar.current.component(.year, from: .now) }

func validatedFilters(_ filters: MovieFilters, currentYear: Int) -> MovieFilters {
    var seenGenres: Set<Int> = []
    let genres = filters.genreIds.filter {
        positionInGenreTable($0) != genreNotInTable && seenGenres.insert($0).inserted
    }
    let validYears = earliestMovieYear...(currentYear + yearsAheadOfToday)
    var from = validYears.contains(filters.fromYear) ? filters.fromYear : noYear
    var to = validYears.contains(filters.toYear) ? filters.toYear : noYear
    if from != noYear && to != noYear && from > to { swap(&from, &to) }
    return MovieFilters(
        genreIds: Array(genres.prefix(maxFilterValues)), fromYear: from, toYear: to,
        people: normalizedFilterNames(filters.people),
        keywords: normalizedFilterNames(filters.keywords),
        title: filters.title.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

private func normalizedFilterNames(_ names: [String]) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []
    for name in names {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX"))
        if !text.isEmpty && seen.insert(key).inserted { result.append(text) }
        if result.count == maxFilterValues { break }
    }
    return result
}

func hasAnyFilter(_ filters: MovieFilters) -> Bool {
    return !filters.genreIds.isEmpty || filters.fromYear != noYear || filters.toYear != noYear
        || !filters.people.isEmpty || !filters.keywords.isEmpty || !filters.title.isEmpty
}

func moviesMatchingFilters(_ movies: [Movie], _ filters: MovieFilters) -> [Movie] {
    return movies.filter { movie in
        if !filters.genreIds.isEmpty && !movie.genreIds.contains(where: filters.genreIds.contains) {
            return false
        }
        if filters.fromYear == noYear && filters.toYear == noYear { return true }
        guard let year = Int(releaseYear(movie)) else { return false }
        return (filters.fromYear == noYear || year >= filters.fromYear)
            && (filters.toYear == noYear || year <= filters.toYear)
    }
}

func yearRangeText(fromYear: Int, toYear: Int) -> String {
    if fromYear == noYear && toYear == noYear { return "" }
    if fromYear == noYear { return "up to \(toYear)" }
    if toYear == noYear { return "\(fromYear) or later" }
    if fromYear == toYear { return String(fromYear) }
    return "\(fromYear)–\(toYear)"
}

func filtersSummary(_ filters: MovieFilters) -> String {
    var parts = filters.genreIds.map(genreName)
    parts.append(yearRangeText(fromYear: filters.fromYear, toYear: filters.toYear))
    parts += filters.people + filters.keywords
    parts.append(filters.title)
    return parts.filter { !$0.isEmpty }.joined(separator: textSeparator)
}

func limitedMovieWish(_ wish: String) -> String {
    let text = wish.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(String.UnicodeScalarView(text.unicodeScalars.prefix(maxWishLength)))
}
