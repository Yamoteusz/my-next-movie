import SwiftUI

struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                syncSection
                signOutSection
            }
            .navigationTitle("Account")
        }
    }

    private var accountSection: some View {
        Section("Signed in as") { Text(viewModel.signedInEmail) }
    }

    private var syncSection: some View {
        Section("Saved movies") { syncStatus }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch viewModel.syncState {
        case .idle:
            Text("Your saved movies sync with your account.")
        case .loading:
            HStack {
                ProgressView()
                Text("Syncing with your account")
            }
        case .loaded:
            Label("In sync with your account", systemImage: "checkmark.circle")
        case .failed:
            Text(viewModel.syncErrorMessage).foregroundStyle(.red)
            Button("Try again") { Task { await viewModel.syncSavedMovies() } }
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) { Task { await viewModel.signOut() } }
                .disabled(viewModel.isSigningOut)
            if viewModel.state == .failed { Text(viewModel.errorMessage).foregroundStyle(.red) }
        } footer: {
            Text(
                "Saved movies stay in your account and are removed from this device when you sign out."
            )
        }
    }
}

#Preview { AccountView(viewModel: previewAccountViewModel(signedInEmail: "test@test.test")) }
