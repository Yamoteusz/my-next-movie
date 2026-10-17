import SwiftUI

struct SignInView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: spacingExtraLarge) {
                heading
                fields
                actions
                status
            }
            .padding(spacingHuge)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }

    private var heading: some View {
        VStack(spacing: spacingMedium) {
            Image(systemName: symbolNameMovies).font(.largeTitle)
            Text("My Next Movie").font(.largeTitle.bold())
            Text("Sign in to keep your watchlist on all your devices.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, spacingHuge)
    }

    private var fields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password).onSubmit { Task { await viewModel.signIn() } }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var actions: some View {
        VStack(spacing: spacingMedium) {
            Button("Sign In") { Task { await viewModel.signIn() } }
                .buttonStyle(.borderedProminent).disabled(!viewModel.canSignIn)
            Button("Create Account") { Task { await viewModel.signUp() } }
                .buttonStyle(.bordered).disabled(!viewModel.canSignUp)
        }
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Text(viewModel.errorMessage).foregroundStyle(.red)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and follow the confirmation link before signing in.")
        } else {
            Text("New accounts need at least \(minimumPasswordLength) password characters.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

#Preview { SignInView(viewModel: previewAccountViewModel(signedInEmail: "")) }
