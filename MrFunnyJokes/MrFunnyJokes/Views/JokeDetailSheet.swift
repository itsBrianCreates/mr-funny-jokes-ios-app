import SwiftUI

struct JokeDetailSheet: View {
    let joke: Joke
    let isCopied: Bool
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
    let onSave: () -> Void

    /// Tracks whether the joke ID was copied to clipboard
    @State private var isJokeIdCopied = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Setup and Punchline - formatted differently for knock-knock jokes
                    if joke.category == .knockKnock {
                        knockKnockContent
                    } else {
                        standardContent
                    }

                    // Character and Category
                    HStack(spacing: 8) {
                        // Character indicator (if available)
                        if let character = jokeCharacter {
                            CharacterIndicatorView(character: character)
                        }

                        // Category
                        HStack(spacing: 4) {
                            Image(systemName: joke.category.icon)
                            Text(joke.category.rawValue)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Rating section
                    BinaryRatingView(currentRating: joke.userRating, onRate: onRate)

                    Divider()

                    // Action buttons - iOS style
                    VStack(spacing: 12) {
                        Button {
                            onSave()
                            HapticManager.shared.lightTap()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: joke.isSaved ? "person.fill" : "person")
                                    .contentTransition(.symbolEffect(.replace))
                                Text(joke.isSaved ? "Saved" : "Save")
                            }
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(joke.isSaved ? .green : .blue)
                        .animation(.easeInOut(duration: 0.2), value: joke.isSaved)

                        Button {
                            onCopy()
                        } label: {
                            HStack {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                                Text(isCopied ? "Copied" : "Copy")
                            }
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(isCopied ? .green : .blue)
                        .animation(.easeInOut(duration: 0.2), value: isCopied)

                        Button {
                            onShare()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }

                    // Joke ID for Firebase reference - tap to copy
                    if let jokeId = joke.firestoreId {
                        Button {
                            UIPasteboard.general.string = jokeId
                            isJokeIdCopied = true

                            // Reset after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isJokeIdCopied = false
                            }
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(isJokeIdCopied ? "Copied!" : "Joke ID")
                                    Image(systemName: isJokeIdCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.caption2)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .font(.caption2)
                                .foregroundColor(isJokeIdCopied ? .green : Color(.tertiaryLabel))

                                Text(jokeId)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(isJokeIdCopied ? .green : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isJokeIdCopied ? Color.green.opacity(0.1) : Color.clear)
                            )
                            .animation(.easeInOut(duration: 0.2), value: isJokeIdCopied)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Standard Joke Content

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Setup
            Text(joke.setup)
                .font(.title2.weight(.medium))

            // Punchline
            Text(joke.punchline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Knock-Knock Joke Content

    private var knockKnockContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parse and format the setup (e.g., "Knock knock. Who's there? Lettuce.")
            ForEach(formatKnockKnockSetup(), id: \.self) { line in
                Text(line)
                    .font(.title3.weight(.medium))
            }

            // Punchline (e.g., "Lettuce who? Lettuce in, it's cold out here!")
            ForEach(formatKnockKnockPunchline(), id: \.self) { line in
                Text(line)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func formatKnockKnockSetup() -> [String] {
        // Format knock-knock setup into lines
        // Input: "Knock, knock. Who's there? Nobel."
        // Output: ["Knock, knock. Who's there?", "Nobel."]
        var lines: [String] = []

        // Find "Who's there?" and split there
        if let range = joke.setup.range(of: "Who's there?", options: .caseInsensitive) {
            // First line: everything up to and including "Who's there?"
            let firstLine = String(joke.setup[...range.upperBound])
            lines.append(firstLine)

            // Second line: the answer (e.g., "Nobel.")
            let answer = String(joke.setup[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            if !answer.isEmpty {
                // Ensure proper capitalization and ending punctuation
                var formattedAnswer = answer.prefix(1).uppercased() + answer.dropFirst()
                if !formattedAnswer.hasSuffix(".") && !formattedAnswer.hasSuffix("!") {
                    formattedAnswer += "."
                }
                lines.append(formattedAnswer)
            }
        } else {
            // Fallback: return the setup as-is
            lines.append(joke.setup)
        }

        return lines
    }

    private func formatKnockKnockPunchline() -> [String] {
        var lines: [String] = []
        let punchline = joke.punchline

        // Look for "[name] who?" pattern
        if let whoRange = punchline.range(of: " who?", options: .caseInsensitive) {
            let questionPart = String(punchline[..<whoRange.upperBound])
            let answerPart = String(punchline[whoRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            lines.append(questionPart)
            if !answerPart.isEmpty {
                lines.append(answerPart)
            }
        } else {
            // Fallback: just return the punchline as-is
            lines.append(punchline)
        }

        return lines
    }
}

#Preview("Dad Joke") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            JokeDetailSheet(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why don't scientists trust atoms?",
                    punchline: "Because they make up everything!",
                    userRating: 5,
                    firestoreId: "0CDqve8AUmDb0VbXWwdQ",
                    character: "Mr. Funny"
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )
        }
}

#Preview("Knock-Knock") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            JokeDetailSheet(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock, knock. Who's there? Nobel.",
                    punchline: "Nobel who? Nobel … that's why I knocked.",
                    userRating: 1,
                    firestoreId: "ABC123XYZ456example",
                    character: "Mr. Potty"
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )
        }
}
