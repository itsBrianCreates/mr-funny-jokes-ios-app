#if DEBUG
import SwiftUI

/// Debug builds only. Launch with `-renderShareCards` to write every share card style
/// and format, for a spread of joke shapes, to the app's Documents/ShareCards folder:
///
///     xcrun simctl launch booted com.mrfunnyjokes.app -renderShareCards
///     open "$(xcrun simctl get_app_container booted com.mrfunnyjokes.app data)/Documents/ShareCards"
///
/// The quickest way to check that short, long and knock-knock jokes all fit.
@MainActor
enum ShareCardDebugRenderer {
    static let samples: [(name: String, joke: Joke)] = [
        ("short", Joke(category: .dadJoke, setup: "What do clouds wear?", punchline: "Thunderwear!", character: "mr_funny")),
        ("medium", Joke(category: .dadJoke, setup: "What are turkeys thankful for on Thanksgiving?", punchline: "Vegetarians.", character: "mr_bad")),
        ("long", Joke(category: .dadJoke, setup: "Sad news. I broke up with my girlfriend Lorraine because I was seeing another girl named Claire Lee.", punchline: "But the good news is that I can see Claire Lee now Lorraine has gone.", character: "mr_sad")),
        ("oneliner", Joke(category: .dadJoke, setup: "I'm the human equivalent of a typo.", punchline: "", character: "mr_sad")),
        ("midsentence", Joke(category: .pickupLine, setup: "Do you believe in love at first sight,", punchline: "or should I walk by again?", character: "mr_love")),
        ("knock", Joke(category: .knockKnock, setup: "Knock, knock.\nWho's there?\nLettuce.", punchline: "Lettuce who?\nLettuce in, it's cold out here!", character: "mr_potty")),
        ("knock_long", Joke(category: .knockKnock, setup: "Knock, knock.\nWho's there?\nBanana.", punchline: "Banana who?\nKnock, knock. Who's there? Banana. Banana who? Knock, knock. Who's there? Orange. Orange who? Orange you glad I didn't say banana?", character: "mr_funny"))
    ]

    static func renderIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-renderShareCards") else { return }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShareCards", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for sample in samples {
            for style in ShareCardStyle.allCases {
                for format in ShareCardFormat.allCases {
                    guard let image = JokeShareCardView.render(joke: sample.joke, style: style, format: format),
                          let data = image.jpegData(compressionQuality: 0.85) else { continue }
                    let file = folder.appendingPathComponent("\(sample.name)-\(style.rawValue)-\(format.rawValue).jpg")
                    try? data.write(to: file)
                }
            }
        }
        print("Share cards written to \(folder.path)")
    }
}
#endif
