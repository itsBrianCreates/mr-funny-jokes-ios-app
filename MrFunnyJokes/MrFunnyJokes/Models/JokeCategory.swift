import SwiftUI

enum JokeCategory: String, Codable, CaseIterable, Identifiable {
    case dadJoke = "Dad Jokes"
    case knockKnock = "Knock-Knock Jokes"
    case pickupLine = "Pick Up Lines"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dadJoke:
            return "face.smiling"
        case .knockKnock:
            return "door.left.hand.closed"
        case .pickupLine:
            return "heart.circle"
        }
    }

    var shortName: String {
        switch self {
        case .dadJoke:
            return "Dad"
        case .knockKnock:
            return "Knock"
        case .pickupLine:
            return "Pickup"
        }
    }
}
