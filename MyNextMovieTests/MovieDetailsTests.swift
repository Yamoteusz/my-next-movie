import Foundation
import Testing

@testable import MyNextMovie

@MainActor
struct MovieDetailsDecodingTests {
    @Test func decodesTaglineAndRuntime() throws {
        let details = try matrixDetails()
        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test func decodesCastWithAndWithoutPhoto() throws {
        let cast = try matrixDetails().credits.cast
        #expect(cast[0].profilePath == "/keanu.jpg")
        #expect(cast[1].profilePath == nil)
    }

    @Test func decodesWatchProvidersUnderSlashKey() throws {
        let providers = try matrixDetails().watchProviders.results["PL"]
        #expect(providers?.flatrate?.first?.providerName == "Prime Video")
        #expect(providers?.rent?.first?.providerName == "Apple TV")
        #expect(providers?.buy == nil)
    }

    @Test func decodesCountryCodeOfReleaseDates() throws {
        #expect(try matrixDetails().releaseDates.results.first?.countryCode == "PL")
    }

    @Test func decodesRecommendationsAsMovies() throws {
        #expect(try matrixDetails().recommendations.results.first?.title == "Inception")
    }

    @Test func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedJSON.utf8))
        #expect(details.runtime == nil)
        #expect(formattedRuntime(details).isEmpty)
        #expect(!hasWatchProviders(watchProviders(details, regionCode: "PL")))
    }
}

@MainActor
struct MovieDetailsTests {
    @Test func runtimeInHoursAndMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 136)) == "2h 16m")
        #expect(formattedRuntime(makeMovieDetails(runtime: 120)) == "2h 0m")
    }

    @Test func runtimeUnderAnHourHasOnlyMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 45)) == "45m")
    }

    @Test func runtimeIsEmptyWhenUnknown() {
        #expect(formattedRuntime(makeMovieDetails()).isEmpty)
        #expect(formattedRuntime(makeMovieDetails(runtime: 0)).isEmpty)
    }

    @Test func directorsAreListedOnceEach() throws {
        #expect(directorNames(try matrixDetails()) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test func directorsAreEmptyWithoutDirector() {
        #expect(directorNames(emptyMovieDetails).isEmpty)
    }

    @Test func certificationSkipsEmptyOnes() throws {
        let details = try matrixDetails()
        #expect(ageCertification(details, regionCode: "PL") == "16")
        #expect(ageCertification(details, regionCode: "US") == "R")
    }

    @Test func certificationIsEmptyForOtherCountry() throws {
        #expect(ageCertification(try matrixDetails(), regionCode: "DE").isEmpty)
    }

    @Test func officialTrailerWins() throws {
        #expect(trailerKey(try matrixDetails()) == "official")
    }

    @Test func unofficialTrailerWhenNoOfficial() {
        let details = makeMovieDetails(videos: [
            Video(key: "fan", site: "YouTube", type: "Trailer", official: false)
        ])
        #expect(trailerKey(details) == "fan")
    }

    @Test func trailerOnOtherSiteIsSkipped() {
        let details = makeMovieDetails(videos: [
            Video(key: "other", site: "Vimeo", type: "Trailer", official: true)
        ])
        #expect(trailerKey(details).isEmpty)
        #expect(!hasTrailer(details))
    }

    @Test func trailerURLPointsToYouTube() throws {
        #expect(
            trailerURL(try matrixDetails())?.absoluteString
                == "https://www.youtube.com/watch?v=official")
    }

    @Test func factsLineAddsRuntimeAndCertification() throws {
        #expect(
            movieFactsLine(testMovies[0], try matrixDetails(), regionCode: "PL")
                == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test func factsLineBeforeDetailsLoad() {
        #expect(
            movieFactsLine(testMovies[0], emptyMovieDetails, regionCode: "PL") == "1999 · ★ 8.2")
    }

    @Test func profileURLIsNilWithoutPhoto() throws {
        let cast = try matrixDetails().credits.cast
        #expect(profileURL(cast[0])?.absoluteString == "https://image.tmdb.org/t/p/w185/keanu.jpg")
        #expect(profileURL(cast[1]) == nil)
    }
}

@MainActor
private func matrixDetails() throws -> MovieDetails {
    return try decodeTMDBMovieDetails(Data(matrixJSON.utf8))
}

private let announcedJSON = """
    {"id":1,"tagline":"","runtime":null,"credits":{"cast":[],"crew":[]},"videos":{"results":[]},
    "release_dates":{"results":[]},"watch/providers":{"results":{}},"recommendations":{"results":[]}}
    """

private let matrixJSON = """
    {"id":603,"tagline":"Believe the unbelievable.","runtime":136,
    "credits":{"cast":[{"id":1,"name":"Keanu Reeves","character":"Neo","profile_path":"/keanu.jpg"},
    {"id":2,"name":"Carrie-Anne Moss","character":"Trinity","profile_path":null}],
    "crew":[{"id":3,"name":"Lana Wachowski","job":"Director"},
    {"id":3,"name":"Lana Wachowski","job":"Director"},{"id":4,"name":"Lilly Wachowski","job":"Director"}]},
    "videos":{"results":[{"key":"fan","site":"YouTube","type":"Trailer","official":false},
    {"key":"official","site":"YouTube","type":"Trailer","official":true}]},
    "release_dates":{"results":[{"iso_3166_1":"PL","release_dates":[{"certification":"","release_date":"1999-03-31T00:00:00.000Z","type":3},{"certification":"16","release_date":"1999-03-31T00:00:00.000Z","type":3}]},
    {"iso_3166_1":"US","release_dates":[{"certification":"R","release_date":"1999-03-31T00:00:00.000Z","type":3}]}]},
    "watch/providers":{"results":{"PL":{"link":"https://example.com/watch",
    "flatrate":[{"provider_id":119,"provider_name":"Prime Video","logo_path":"/prime.png"}],
    "rent":[{"provider_id":2,"provider_name":"Apple TV","logo_path":null}]}}},
    "recommendations":{"results":[{"id":27205,"title":"Inception","overview":"Dreams.",
    "release_date":"2010-07-15","poster_path":null,"vote_average":8.4,"genre_ids":[28]}]}}
    """

@MainActor
struct InCinemasTests {
    private let today = Date(timeIntervalSince1970: 1_793_923_200)

    @Test func recentCinemaPremiereIsInCinemas() {
        #expect(
            isInCinemas(cinemaRelease("2026-10-17T00:00:00.000Z"), regionCode: "PL", today: today))
    }

    @Test func limitedReleaseCountsToo() {
        #expect(isInCinemas(cinemaRelease("2026-10-17", type: 2), regionCode: "PL", today: today))
    }

    @Test func oldPremiereIsNotInCinemas() {
        #expect(!isInCinemas(cinemaRelease("2026-08-01"), regionCode: "PL", today: today))
    }

    @Test func futurePremiereIsNotInCinemasYet() {
        #expect(!isInCinemas(cinemaRelease("2026-11-07"), regionCode: "PL", today: today))
        #expect(daysSinceReleaseDay("2026-11-07", today: today) == -1)
    }

    @Test func digitalReleaseIsNotCinema() {
        #expect(!isInCinemas(cinemaRelease("2026-10-17", type: 4), regionCode: "PL", today: today))
    }

    @Test func premiereInAnotherCountryDoesNotCount() {
        #expect(
            !isInCinemas(cinemaRelease("2026-10-17", country: "US"), regionCode: "PL", today: today)
        )
    }

    @Test func unreadableDateIsNotInCinemas() {
        #expect(!isInCinemas(cinemaRelease("not-a-date"), regionCode: "PL", today: today))
        #expect(daysSinceReleaseDay("2026-02-30", today: today) == -1)
        #expect(daysSinceReleaseDay("", today: today) == -1)
    }

    @Test func runIncludesReleaseDayAndDay42ButNot43() {
        #expect(daysSinceReleaseDay("2026-11-06", today: today) == 0)
        #expect(isInCinemas(cinemaRelease("2026-11-06"), regionCode: "PL", today: today))
        #expect(daysSinceReleaseDay("2026-09-25", today: today) == 42)
        #expect(isInCinemas(cinemaRelease("2026-09-25"), regionCode: "PL", today: today))
        #expect(!isInCinemas(cinemaRelease("2026-09-24"), regionCode: "PL", today: today))
    }

    @Test func computesCalendarDaysIndependentlyOfTimeOfDay() {
        #expect(daysSinceReleaseDay("2026-11-05T23:59:59.000Z", today: today) == 1)
        #expect(daysSinceReleaseDay("2026-11-06T23:59:59.000Z", today: today) == 0)
    }
}
