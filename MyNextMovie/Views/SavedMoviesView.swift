import SwiftData
import SwiftUI

struct SavedMoviesView: View {
    @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
    let loadDetails: MovieDetailsLoader

    var body: some View {
        NavigationStack {
            content.navigationTitle("Saved")
                .navigationDestination(for: Movie.self, destination: detailView)
        }
    }

    private func detailView(_ movie: Movie) -> some View {
        MovieDetailView(movie: movie, loadDetails: loadDetails)
    }

    @ViewBuilder
    private var content: some View {
        if savedMovies.isEmpty {
            ContentUnavailableView(
                "No saved movies", systemImage: symbolNameSaved,
                description: Text("Use the bookmark on a movie's details to save it for later.")
            )
        } else {
            MovieGrid(title: "Watch Later", movies: moviesFromSaved(savedMovies))
        }
    }
}

struct SaveMovieButton: View {
    let movie: Movie
    @Environment(\.modelContext) private var modelContext
    @Query private var savedCopies: [SavedMovie]

    init(movie: Movie) {
        self.movie = movie
        let movieId = movie.id
        _savedCopies = Query(filter: #Predicate<SavedMovie> { $0.movieId == movieId })
    }

    var body: some View {
        Button {
            toggleSavedMovie(modelContext, movie, now: .now)
        } label: {
            Label(
                savedCopies.isEmpty ? "Save movie" : "Remove saved movie",
                systemImage: savedCopies.isEmpty ? symbolNameSaved : symbolNameSavedFilled
            )
        }
    }
}

#Preview {
    SavedMoviesView(loadDetails: fetchMovieDetails)
        .modelContainer(for: storedModelTypes, inMemory: true)
}
