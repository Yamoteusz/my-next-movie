import SwiftUI

private let maximumCastCount = 15
private let castPhotoSize: CGFloat = 80
private let castCardWidth: CGFloat = 100
private let providerLogoSize: CGFloat = 44
private let providerCardWidth: CGFloat = 100
private let recommendedCardWidth: CGFloat = 150

struct MovieDetailSections: View {
    let details: MovieDetails
    private var providers: CountryWatchProviders {
        return watchProviders(details, regionCode: watchRegionCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            trailer

            if !details.credits.cast.isEmpty { CastSection(cast: details.credits.cast) }
            if hasWatchProviders(providers) { WatchProvidersSection(providers: providers) }
            if !details.recommendations.results.isEmpty {
                RecommendationsSection(movies: details.recommendations.results)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var trailer: some View {
        if let address = trailerURL(details) {
            Link(destination: address) { trailerLabel }.buttonStyle(.borderedProminent)
        }
    }

    private var trailerLabel: some View {
        Label("Watch Trailer", systemImage: "play.circle.fill")
    }
}

private struct CastSection: View {
    let cast: [CastMember]
    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("Cast").font(.title2.bold())
            ScrollView(.horizontal, showsIndicators: false) { castRow }
        }
    }

    private var castRow: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(Array(cast.prefix(maximumCastCount))) { member in CastCard(member: member) }
        }
    }
}

private struct CastCard: View {
    let member: CastMember
    var body: some View {
        VStack(spacing: spacingSmall) {
            photo
            Text(member.name).font(.caption.weight(.semibold))
            Text(member.character).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: castCardWidth).multilineTextAlignment(.center)
    }

    private var photo: some View {
        AsyncImage(url: profileURL(member)) { phase in
            if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
        }
        .frame(width: castPhotoSize, height: castPhotoSize).clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.fill").resizable().scaledToFit().padding(spacingLarge)
            .foregroundStyle(.secondary).background(.quaternary)
    }
}

private struct WatchProvidersSection: View {
    let providers: CountryWatchProviders
    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("Where to Watch").font(.title2.bold())
            ProviderGroup(title: "Stream", providers: providers.flatrate ?? [])
            ProviderGroup(title: "Rent", providers: providers.rent ?? [])
            ProviderGroup(title: "Buy", providers: providers.buy ?? [])
            attribution
        }
    }

    @ViewBuilder
    private var attribution: some View {
        if let address = URL(string: providers.link), address.scheme == "https" {
            Link("Streaming data from JustWatch", destination: address).font(.caption)
        } else {
            Text("Streaming data from JustWatch").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ProviderGroup: View {
    let title: String
    let providers: [WatchProvider]
    var body: some View {
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: spacingSmall) {
                Text(title).font(.headline)
                ScrollView(.horizontal, showsIndicators: false) { row }
            }
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(providers) { provider in ProviderCard(provider: provider) }
        }
    }
}

private struct ProviderCard: View {
    let provider: WatchProvider
    var body: some View {
        VStack(spacing: spacingSmall) {
            logo
            Text(provider.providerName).font(.caption).multilineTextAlignment(.center)
        }
        .frame(width: providerCardWidth)
    }

    private var logo: some View {
        AsyncImage(url: logoURL(provider)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "tv")
            }
        }
        .frame(width: providerLogoSize, height: providerLogoSize)
        .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
    }
}

private struct RecommendationsSection: View {
    let movies: [Movie]
    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("More Like This").font(.title2.bold())
            ScrollView(.horizontal, showsIndicators: false) { row }
                .scrollClipDisabled()
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: spacingLarge) {
            ForEach(movies) { movie in recommendation(movie) }
        }
    }

    private func recommendation(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie).frame(width: recommendedCardWidth)
        }
        .buttonStyle(.plain)
    }
}
