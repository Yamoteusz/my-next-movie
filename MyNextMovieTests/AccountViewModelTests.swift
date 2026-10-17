import Testing

@testable import MyNextMovie

@MainActor
struct AccountViewModelTests {
    @Test func startsSignedOut() {
        #expect(!TestAccount().viewModel().isSignedIn)
    }

    @Test func newAccountNeedsLongEnoughPassword() {
        let model = TestAccount().viewModel()
        model.email = "user@example.com"
        model.password = "test"
        #expect(model.canSignIn)
        #expect(!model.canSignUp)
        model.password = "long-enough"
        #expect(model.canSignUp)
    }

    @Test func signInTrimsEmailClearsPasswordAndSyncs() async {
        let account = TestAccount()
        let model = account.viewModel()
        model.email = " user@example.com "
        model.password = "password"
        await model.signIn()
        #expect(model.signedInEmail == "user@example.com")
        #expect(model.password.isEmpty)
        #expect(account.syncCount == 1)
        #expect(model.state == .loaded)
    }

    @Test func showsErrorWhenSignInFails() async {
        let account = TestAccount()
        account.isOffline = true
        let model = account.readyModel()
        await model.signIn()
        #expect(model.state == .failed)
        #expect(model.errorMessage == "No connection")
        #expect(!model.isSignedIn)
    }

    @Test func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let account = TestAccount()
        let model = account.readyModel()
        await model.signUp()
        #expect(model.isSignedIn)
        #expect(!model.isWaitingForEmailConfirmation)
        #expect(account.syncCount == 1)
    }

    @Test func signUpWaitsForEmailConfirmation() async {
        let account = TestAccount()
        account.needsConfirmation = true
        let model = account.readyModel()
        await model.signUp()
        #expect(model.isWaitingForEmailConfirmation)
        #expect(!model.isSignedIn)
        #expect(account.syncCount == 0)
    }

    @Test func userFromLastTimeIsSignedInAtOnce() {
        let account = TestAccount()
        account.email = "existing@example.com"
        #expect(account.viewModel().signedInEmail == "existing@example.com")
    }

    @Test func doesNotSyncWhenSignedOut() async {
        let account = TestAccount()
        await account.viewModel().syncSavedMovies()
        #expect(account.syncCount == 0)
    }

    @Test func showsErrorWhenSyncFails() async {
        let account = TestAccount()
        account.email = "existing@example.com"
        account.isOffline = true
        let model = account.viewModel()
        await model.syncSavedMovies()
        #expect(model.syncState == .failed)
        #expect(model.syncErrorMessage == "No connection")
    }

    @Test func syncWorksAgainAfterFailure() async {
        let account = TestAccount()
        account.email = "existing@example.com"
        account.isOffline = true
        let model = account.viewModel()
        await model.syncSavedMovies()
        account.isOffline = false
        await model.syncSavedMovies()
        #expect(model.syncState == .loaded)
        #expect(model.syncErrorMessage.isEmpty)
    }

    @Test func signOutSyncsThenClearsDevice() async {
        let account = TestAccount()
        account.email = "existing@example.com"
        let model = account.viewModel()
        await model.signOut()
        #expect(!model.isSignedIn)
        #expect(account.events == ["sync", "signOut", "clear"])
        #expect(account.clearCount == 1)
    }

    @Test func concurrentSyncRequestsRunSeriallyAndCoalesce() async {
        var activeCount = 0
        var maximumActive = 0
        var calls = 0
        var release: CheckedContinuation<Void, Never>?
        let account = TestAccount()
        account.email = "user@example.com"
        let model = AccountViewModel(
            account: account.service(),
            syncSavedMovies: {
                calls += 1
                activeCount += 1
                maximumActive = max(maximumActive, activeCount)
                if calls == 1 { await withCheckedContinuation { release = $0 } }
                activeCount -= 1
            }, clearSavedMovies: {}
        )
        let first = Task { await model.syncSavedMovies() }
        while release == nil { await Task.yield() }
        let second = Task { await model.syncSavedMovies() }
        let third = Task { await model.syncSavedMovies() }
        await Task.yield()
        release?.resume()
        await first.value
        await second.value
        await third.value
        #expect(maximumActive == 1)
        #expect(calls == 2)
    }
}

@MainActor
private final class TestAccount {
    var email = ""
    var isOffline = false
    var needsConfirmation = false
    var syncCount = 0
    var clearCount = 0
    var events: [String] = []

    func service() -> AccountService {
        return AccountService(
            signedInEmail: { self.email },
            signIn: { email, _ in
                if self.isOffline { throw NoConnection() }
                self.email = email
                return email
            },
            signUp: { email, _ in
                if self.isOffline { throw NoConnection() }
                self.email = self.needsConfirmation ? "" : email
                return self.email
            },
            signOut: {
                self.events.append("signOut")
                self.email = ""
            }
        )
    }

    func viewModel() -> AccountViewModel {
        return AccountViewModel(
            account: service(),
            syncSavedMovies: {
                self.syncCount += 1
                self.events.append("sync")
                if self.isOffline { throw NoConnection() }
            },
            clearSavedMovies: {
                self.events.append("clear")
                self.clearCount += 1
            }
        )
    }

    func readyModel() -> AccountViewModel {
        let model = viewModel()
        model.email = "user@example.com"
        model.password = "password"
        return model
    }
}
