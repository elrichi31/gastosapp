import Testing
@testable import Zenlor

struct BackendURLPreferenceTests {
    private let current = "https://spend.zenlorlabs.com"

    @Test func migratesRetiredDomainsIncludingSavedIPhoneURL() {
        for old in ["https://bethaspend.bethalabs.com", "https://bethaspend.bethalabs.com/", " HTTPS://BETHASPEND.BETHALABS.COM/ ", "https://zenlor.app"] {
            #expect(BackendURLPreference.resolve(storedURL: old, configuredURL: current) == current)
        }
    }

    @Test func keepsCurrentDomainAndCustomDevelopmentServer() {
        for url in [current, "http://localhost:3000", "https://staging.example.com", "https://bethaspend.bethalabs.com/custom"] {
            #expect(BackendURLPreference.resolve(storedURL: url, configuredURL: current) == url)
        }
    }

    @Test func usesConfiguredServerForMissingPreferences() {
        #expect(BackendURLPreference.resolve(storedURL: nil, configuredURL: current) == current)
        #expect(BackendURLPreference.resolve(storedURL: "  ", configuredURL: current) == current)
    }
}
