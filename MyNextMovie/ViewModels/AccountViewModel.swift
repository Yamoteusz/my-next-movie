import Foundation
import Observation

@Observable
final class AccountViewModel {
    var email = ""
    var password = ""
    private(set) var signedInEmail: String
    private(set) var state = LoadState.idle
    private(set) var errorMessage = ""
    private(set) var isWaitingForEmailConfirmation = false
    private(set) var syncState = LoadState.idle
    private(set) var syncErrorMessage = ""
    private(set) var isSigningOut = false

    private let account: AccountService
    private let synchronize: () async throws -> Void
    private let clearSavedMovies: @MainActor () -> Void
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var syncRequested = false

    init(
        account: AccountService, syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        synchronize = syncSavedMovies
        self.clearSavedMovies = clearSavedMovies
        signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool { return !signedInEmail.isEmpty }
    var canSignIn: Bool {
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty && state != .loading
    }
    var canSignUp: Bool { return canSignIn && password.count >= minimumPasswordLength }

    func signIn() async {
        guard canSignIn else { return }
        await submit(account.signIn)
    }

    func signUp() async {
        guard canSignUp else { return }
        await submit(account.signUp)
    }

    private func submit(_ request: AccountRequest) async {
        state = .loading
        errorMessage = ""
        isWaitingForEmailConfirmation = false
        do {
            signedInEmail = try await request(
                email.trimmingCharacters(in: .whitespacesAndNewlines), password)
            password = ""
            isWaitingForEmailConfirmation = signedInEmail.isEmpty
            state = .loaded
            await syncSavedMovies()
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
    }

    func syncSavedMovies() async {
        guard isSignedIn else { return }
        if let syncTask {
            syncRequested = true
            await syncTask.value
            return
        }
        let task = Task { await runSyncRequests() }
        syncTask = task
        await task.value
        syncTask = nil
    }

    private func runSyncRequests() async {
        repeat {
            syncRequested = false
            syncState = .loading
            syncErrorMessage = ""
            do {
                try await synchronize()
                syncState = .loaded
            } catch {
                syncState = .failed
                syncErrorMessage = error.localizedDescription
            }
        } while syncRequested && isSignedIn
    }

    func signOut() async {
        guard isSignedIn && !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await syncSavedMovies()
        do {
            try await account.signOut()
            clearSavedMovies()
            signedInEmail = ""
            password = ""
            state = .idle
            syncState = .idle
            syncErrorMessage = ""
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
    }
}

func previewAccountViewModel(signedInEmail: String) -> AccountViewModel {
    return AccountViewModel(
        account: AccountService(
            signedInEmail: { signedInEmail }, signIn: { email, _ in email },
            signUp: { email, _ in email }, signOut: {}
        ), syncSavedMovies: {}, clearSavedMovies: {}
    )
}
