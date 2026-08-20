import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Hashable {
    // Video
    case netflix, disneyPlus, max, primeVideo, appleTV, hulu, paramount, crunchyroll, youtubePremium
    // Música
    case spotify, appleMusic, youtubeMusic, tidal, deezer, amazonMusic
    // Nube / productividad
    case iCloud, googleOne, dropbox, microsoft365, notion, adobeCC, canva, figma
    // Gaming
    case psPlus, xboxGamePass, nintendoOnline, appleArcade
    // AI / dev
    case chatgptPlus, claudePro, copilot, cursor, perplexity
    // Fitness / salud
    case strava, calm, headspace, myFitnessPal
    // Lectura
    case nyt, audible, kindleUnlimited, medium
    // Otros
    case linkedinPremium, patreon

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .netflix: return "Netflix"
        case .disneyPlus: return "Disney+"
        case .max: return "Max"
        case .primeVideo: return "Prime Video"
        case .appleTV: return "Apple TV+"
        case .hulu: return "Hulu"
        case .paramount: return "Paramount+"
        case .crunchyroll: return "Crunchyroll"
        case .youtubePremium: return "YouTube Premium"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .youtubeMusic: return "YouTube Music"
        case .tidal: return "Tidal"
        case .deezer: return "Deezer"
        case .amazonMusic: return "Amazon Music"
        case .iCloud: return "iCloud+"
        case .googleOne: return "Google One"
        case .dropbox: return "Dropbox"
        case .microsoft365: return "Microsoft 365"
        case .notion: return "Notion"
        case .adobeCC: return "Adobe CC"
        case .canva: return "Canva Pro"
        case .figma: return "Figma"
        case .psPlus: return "PlayStation+"
        case .xboxGamePass: return "Xbox Game Pass"
        case .nintendoOnline: return "Nintendo Online"
        case .appleArcade: return "Apple Arcade"
        case .chatgptPlus: return "ChatGPT Plus"
        case .claudePro: return "Claude Pro"
        case .copilot: return "GitHub Copilot"
        case .cursor: return "Cursor"
        case .perplexity: return "Perplexity Pro"
        case .strava: return "Strava"
        case .calm: return "Calm"
        case .headspace: return "Headspace"
        case .myFitnessPal: return "MyFitnessPal"
        case .nyt: return "NYT"
        case .audible: return "Audible"
        case .kindleUnlimited: return "Kindle Unlimited"
        case .medium: return "Medium"
        case .linkedinPremium: return "LinkedIn Premium"
        case .patreon: return "Patreon"
        }
    }

    /// Iniciales que se muestran en el badge cuando no hay logo real.
    var iniciales: String {
        switch self {
        case .netflix: return "N"
        case .disneyPlus: return "D+"
        case .max: return "M"
        case .primeVideo: return "PV"
        case .appleTV: return "tv"
        case .hulu: return "h"
        case .paramount: return "P+"
        case .crunchyroll: return "Cr"
        case .youtubePremium: return "YT"
        case .spotify: return "S"
        case .appleMusic: return "M"
        case .youtubeMusic: return "YM"
        case .tidal: return "T"
        case .deezer: return "D"
        case .amazonMusic: return "aM"
        case .iCloud: return "iC"
        case .googleOne: return "G1"
        case .dropbox: return "D"
        case .microsoft365: return "M365"
        case .notion: return "N"
        case .adobeCC: return "Ai"
        case .canva: return "C"
        case .figma: return "F"
        case .psPlus: return "PS+"
        case .xboxGamePass: return "GP"
        case .nintendoOnline: return "NS"
        case .appleArcade: return "A"
        case .chatgptPlus: return "GPT"
        case .claudePro: return "C"
        case .copilot: return "GH"
        case .cursor: return "Cu"
        case .perplexity: return "P"
        case .strava: return "S"
        case .calm: return "C"
        case .headspace: return "H"
        case .myFitnessPal: return "MFP"
        case .nyt: return "NYT"
        case .audible: return "a"
        case .kindleUnlimited: return "KU"
        case .medium: return "M"
        case .linkedinPremium: return "in"
        case .patreon: return "P"
        }
    }

    var color: Color {
        switch self {
        case .netflix: return Color(red: 0.90, green: 0.10, blue: 0.16)
        case .disneyPlus: return Color(red: 0.04, green: 0.13, blue: 0.36)
        case .max: return Color(red: 0.40, green: 0.20, blue: 0.78)
        case .primeVideo: return Color(red: 0.00, green: 0.66, blue: 0.93)
        case .appleTV: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .hulu: return Color(red: 0.11, green: 0.79, blue: 0.42)
        case .paramount: return Color(red: 0.00, green: 0.40, blue: 0.91)
        case .crunchyroll: return Color(red: 0.97, green: 0.45, blue: 0.07)
        case .youtubePremium: return Color(red: 1.00, green: 0.00, blue: 0.00)
        case .spotify: return Color(red: 0.12, green: 0.84, blue: 0.38)
        case .appleMusic: return Color(red: 0.98, green: 0.20, blue: 0.43)
        case .youtubeMusic: return Color(red: 1.00, green: 0.10, blue: 0.10)
        case .tidal: return Color(red: 0.05, green: 0.05, blue: 0.07)
        case .deezer: return Color(red: 0.65, green: 0.27, blue: 0.95)
        case .amazonMusic: return Color(red: 0.16, green: 0.58, blue: 0.85)
        case .iCloud: return Color(red: 0.32, green: 0.66, blue: 0.96)
        case .googleOne: return Color(red: 0.94, green: 0.27, blue: 0.20)
        case .dropbox: return Color(red: 0.00, green: 0.41, blue: 0.92)
        case .microsoft365: return Color(red: 0.85, green: 0.30, blue: 0.10)
        case .notion: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .adobeCC: return Color(red: 0.92, green: 0.10, blue: 0.10)
        case .canva: return Color(red: 0.00, green: 0.78, blue: 0.93)
        case .figma: return Color(red: 0.96, green: 0.30, blue: 0.10)
        case .psPlus: return Color(red: 0.00, green: 0.27, blue: 0.61)
        case .xboxGamePass: return Color(red: 0.06, green: 0.45, blue: 0.06)
        case .nintendoOnline: return Color(red: 0.90, green: 0.05, blue: 0.16)
        case .appleArcade: return Color(red: 0.42, green: 0.32, blue: 0.94)
        case .chatgptPlus: return Color(red: 0.06, green: 0.65, blue: 0.50)
        case .claudePro: return Color(red: 0.83, green: 0.49, blue: 0.27)
        case .copilot: return Color(red: 0.13, green: 0.13, blue: 0.13)
        case .cursor: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .perplexity: return Color(red: 0.10, green: 0.51, blue: 0.50)
        case .strava: return Color(red: 0.99, green: 0.36, blue: 0.13)
        case .calm: return Color(red: 0.16, green: 0.34, blue: 0.66)
        case .headspace: return Color(red: 0.97, green: 0.46, blue: 0.13)
        case .myFitnessPal: return Color(red: 0.00, green: 0.45, blue: 0.85)
        case .nyt: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .audible: return Color(red: 0.95, green: 0.55, blue: 0.04)
        case .kindleUnlimited: return Color(red: 0.20, green: 0.55, blue: 0.85)
        case .medium: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .linkedinPremium: return Color(red: 0.04, green: 0.46, blue: 0.71)
        case .patreon: return Color(red: 0.96, green: 0.27, blue: 0.10)
        }
    }

    var categoria: ProviderCategoria {
        switch self {
        case .netflix, .disneyPlus, .max, .primeVideo, .appleTV, .hulu, .paramount, .crunchyroll, .youtubePremium:
            return .video
        case .spotify, .appleMusic, .youtubeMusic, .tidal, .deezer, .amazonMusic:
            return .musica
        case .iCloud, .googleOne, .dropbox, .microsoft365, .notion, .adobeCC, .canva, .figma:
            return .nube
        case .psPlus, .xboxGamePass, .nintendoOnline, .appleArcade:
            return .gaming
        case .chatgptPlus, .claudePro, .copilot, .cursor, .perplexity:
            return .ai
        case .strava, .calm, .headspace, .myFitnessPal:
            return .fitness
        case .nyt, .audible, .kindleUnlimited, .medium:
            return .lectura
        case .linkedinPremium, .patreon:
            return .otros
        }
    }
}

enum ProviderCategoria: String, CaseIterable, Identifiable {
    case video = "Video"
    case musica = "Música"
    case nube = "Nube y productividad"
    case gaming = "Gaming"
    case ai = "AI y dev"
    case fitness = "Fitness y salud"
    case lectura = "Lectura"
    case otros = "Otros"

    var id: String { rawValue }

    var icono: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .musica: return "music.note"
        case .nube: return "icloud.fill"
        case .gaming: return "gamecontroller.fill"
        case .ai: return "sparkles"
        case .fitness: return "heart.fill"
        case .lectura: return "book.fill"
        case .otros: return "square.grid.2x2.fill"
        }
    }
}
