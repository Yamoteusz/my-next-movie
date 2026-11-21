import Foundation
import Testing

@testable import MyNextMovie

@MainActor
func makeMovieFilters(
    genres: [Int] = [], from: Int = 0, to: Int = 0, people: [String] = [],
    keywords: [String] = [], title: String = ""
) -> MovieFilters {
    return MovieFilters(
        genreIds: genres, fromYear: from, toYear: to, people: people, keywords: keywords,
        title: title)
}

@MainActor
struct MovieFiltersValidationTests {
    @Test func keepsValidFilters() {
        let filters = makeMovieFilters(
            genres: [35], from: 1990, to: 1999, people: ["Keanu Reeves"], keywords: ["heist"],
            title: "Speed")
        #expect(validatedFilters(filters, currentYear: 2026) == filters)
    }

    @Test func dropsUnknownAndRepeatedGenres() {
        let result = validatedFilters(makeMovieFilters(genres: [35, 1, 35, 28]), currentYear: 2026)
        #expect(result.genreIds == [35, 28])
    }

    @Test func keepsAtMostThreeOfEach() {
        let filters = makeMovieFilters(
            genres: [35, 28, 18, 14], people: ["A", "B", "C", "D"], keywords: ["a", "b", "c", "d"])
        let result = validatedFilters(filters, currentYear: 2026)
        #expect(result.genreIds == [35, 28, 18])
        #expect(result.people == ["A", "B", "C"])
        #expect(result.keywords == ["a", "b", "c"])
    }

    @Test func dropsYearsOutOfRange() {
        let invalid = validatedFilters(makeMovieFilters(from: 1879, to: 2032), currentYear: 2026)
        #expect(invalid.fromYear == noYear)
        #expect(invalid.toYear == noYear)
        let boundary = validatedFilters(makeMovieFilters(from: 1880, to: 2031), currentYear: 2026)
        #expect(boundary.fromYear == 1880)
        #expect(boundary.toYear == 2031)
    }

    @Test func swapsYearsInWrongOrder() {
        let result = validatedFilters(makeMovieFilters(from: 1999, to: 1990), currentYear: 2026)
        #expect(result.fromYear == 1990)
        #expect(result.toYear == 1999)
    }

    @Test func trimsAndDropsEmptyOrRepeatedNames() {
        let filters = makeMovieFilters(
            people: [" Keanu Reeves \n", "", "keanu reeves", "Sandra Bullock"],
            keywords: ["heist", " heist ", "\n"], title: " Speed ")
        let result = validatedFilters(filters, currentYear: 2026)
        #expect(result.people == ["Keanu Reeves", "Sandra Bullock"])
        #expect(result.keywords == ["heist"])
        #expect(result.title == "Speed")
    }

    @Test func emptyFiltersHaveNoFilter() { #expect(!hasAnyFilter(noMovieFilters)) }

    @Test func onlyUnknownGenresLeaveNoFilter() {
        #expect(
            !hasAnyFilter(validatedFilters(makeMovieFilters(genres: [1, 2]), currentYear: 2026)))
    }
}

@MainActor
struct MovieFiltersTextTests {
    @Test func summaryListsEveryFilter() {
        let filters = makeMovieFilters(
            genres: [35, 28], from: 1990, to: 1999, people: ["Keanu Reeves"], keywords: ["heist"],
            title: "Speed")
        #expect(
            filtersSummary(filters) == "Comedy · Action · 1990–1999 · Keanu Reeves · heist · Speed")
        #expect(filtersSummary(noMovieFilters).isEmpty)
    }

    @Test func yearRangeTextCoversEveryCase() {
        #expect(yearRangeText(fromYear: 0, toYear: 0).isEmpty)
        #expect(yearRangeText(fromYear: 1990, toYear: 0) == "1990 or later")
        #expect(yearRangeText(fromYear: 0, toYear: 1999) == "up to 1999")
        #expect(yearRangeText(fromYear: 1990, toYear: 1999) == "1990–1999")
        #expect(yearRangeText(fromYear: 1990, toYear: 1990) == "1990")
    }

    @Test func decodesAnswerOfTheFunction() throws {
        let json = """
            {"genreIds":[35],"fromYear":1990,"toYear":1999,"people":["Keanu Reeves"],"keywords":[],"title":""}
            """
        let filters = try JSONDecoder().decode(MovieFilters.self, from: Data(json.utf8))
        #expect(
            filters
                == makeMovieFilters(genres: [35], from: 1990, to: 1999, people: ["Keanu Reeves"]))
    }

    @Test func errorAnswerShowsItsMessage() {
        let data = Data("{\"message\":\"Daily limit reached.\"}".utf8)
        #expect(functionErrorMessage(statusCode: 429, data: data) == "Daily limit reached.")
        #expect(functionErrorMessage(statusCode: 503, data: Data()).contains("503"))
        #expect(
            functionErrorMessage(statusCode: 401, data: Data("{\"message\":\" \"}".utf8)).contains(
                "401"))
    }
}

@MainActor
struct DiscoverRequestTests {
    @Test func withoutFiltersHasNoParameters() {
        let request = tmdbDiscoverRequest(noMovieFilters, personIds: [], keywordIds: [])
        #expect(request.path == tmdbPathDiscoverMovies)
        #expect(request.parameters.isEmpty)
    }

    @Test func anyGenreAndKeywordButEveryPerson() {
        let request = tmdbDiscoverRequest(
            makeMovieFilters(genres: [35, 28]), personIds: [6384, 18277], keywordIds: [1, 2])
        #expect(parameter(request, "with_genres") == "35|28")
        #expect(parameter(request, "with_people") == "6384,18277")
        #expect(parameter(request, "with_keywords") == "1|2")
    }

    @Test func yearsCoverWholeYears() {
        let request = tmdbDiscoverRequest(
            makeMovieFilters(from: 1990, to: 1999), personIds: [], keywordIds: [])
        #expect(parameter(request, "primary_release_date.gte") == "1990-01-01")
        #expect(parameter(request, "primary_release_date.lte") == "1999-12-31")
    }

    @Test func nameSearchSendsTheName() {
        let request = tmdbNameSearchRequest(path: tmdbPathSearchPeople, name: "Keanu Reeves")
        #expect(request.path == "/3/search/person")
        #expect(parameter(request, "query") == "Keanu Reeves")
    }

    @Test func firstIdIsTheBestMatch() throws {
        #expect(
            try decodeFirstTMDBId(Data("{\"results\":[{\"id\":6384},{\"id\":1}]}".utf8)) == 6384)
        #expect(try decodeFirstTMDBId(Data("{\"results\":[]}".utf8)) == noTMDBId)
    }
}

@MainActor
func parameter(_ request: TMDBRequest, _ name: String) -> String? {
    return request.parameters.first { $0.name == name }?.value
}
