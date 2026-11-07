import Foundation

@testable import MyNextMovie

@MainActor
let testMovies: [Movie] = [
    Movie(
        id: 603,
        title: "The Matrix",
        overview: "A hacker named Neo learns that the world he lives in is a simulation.",
        releaseDate: "1999-03-31",
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        voteAverage: 8.2,
        genreIds: [genreIdAction, genreIdScienceFiction]
    ),
    Movie(
        id: 27205,
        title: "Inception",
        overview: "A thief who steals secrets from dreams is asked to plant an idea instead.",
        releaseDate: "2010-07-15",
        posterPath: "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg",
        voteAverage: 8.4,
        genreIds: [genreIdAction, genreIdScienceFiction, genreIdAdventure]
    ),
    Movie(
        id: 157336,
        title: "Interstellar",
        overview:
            "A team of astronauts travels through a wormhole to find a new home for humanity.",
        releaseDate: "2014-11-05",
        posterPath: "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
        voteAverage: 8.4,
        genreIds: [genreIdAdventure, genreIdDrama, genreIdScienceFiction]
    ),
    Movie(
        id: 680,
        title: "Pulp Fiction",
        overview: "Several intertwined stories from the Los Angeles criminal underworld.",
        releaseDate: "1994-09-10",
        posterPath: "/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
        voteAverage: 8.5,
        genreIds: [genreIdThriller, genreIdCrime]
    ),
    Movie(
        id: 129,
        title: "Spirited Away",
        overview: "Ten-year-old Chihiro wanders into a world of spirits and must save her parents.",
        releaseDate: "2001-07-20",
        posterPath: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
        voteAverage: 8.5,
        genreIds: [genreIdAnimation, genreIdFamily, genreIdFantasy]
    ),
    Movie(
        id: 546554, title: "Knives Out", overview: "A detective investigates a mysterious death.",
        releaseDate: "2019-11-27", posterPath: "/pThyQovXQrw2m0s9x82twj48Jq4.jpg", voteAverage: 7.8,
        genreIds: [genreIdComedy, genreIdCrime, genreIdMystery]),
    Movie(
        id: 597, title: "Titanic", overview: "Two passengers fall in love aboard the Titanic.",
        releaseDate: "1997-12-19", posterPath: "/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg", voteAverage: 7.9,
        genreIds: [genreIdDrama, genreIdRomance]),
]

@MainActor
let testMovieDetails = makeMovieDetails(runtime: 136)

@MainActor
func makeMovieDetails(runtime: Int? = nil, videos: [Video] = []) -> MovieDetails {
    var details = emptyMovieDetails
    details.id = 603
    details.tagline = "Believe the unbelievable."
    details.runtime = runtime
    details.videos = VideoList(results: videos)
    return details
}

@MainActor
func filterTestMovies(query: String, genreId: Int) async throws -> [Movie] {
    return filterMovies(testMovies, query: query, genreId: genreId)
}

@MainActor
func cinemaRelease(_ date: String, type: Int = 3, country: String = "PL") -> MovieDetails {
    var details = emptyMovieDetails
    details.releaseDates = ReleaseDateList(results: [
        CountryReleaseDates(
            countryCode: country,
            releaseDates: [ReleaseDate(certification: "16", releaseDate: date, type: type)]
        )
    ])
    return details
}
