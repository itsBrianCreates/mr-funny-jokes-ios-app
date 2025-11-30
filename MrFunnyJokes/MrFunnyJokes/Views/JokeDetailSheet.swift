import SwiftUI

struct JokeDetailSheet: View {
    let joke: Joke
    let isCopied: Bool
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

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

                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 8)

                    // Rating section
                    GroanOMeterView(currentRating: joke.userRating, onRate: onRate)

                    Divider()
                        .padding(.vertical, 8)

                    // Action buttons - iOS style
                    VStack(spacing: 12) {
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
        .presentationCornerRadius(20)
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
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func formatKnockKnockSetup() -> [String] {
        // Split by common knock-knock patterns
        var lines: [String] = []
        var remaining = joke.setup

        // Extract "Knock knock"
        if let range = remaining.range(of: "Knock knock", options: .caseInsensitive) {
            lines.append("Knock knock!")
            remaining = String(remaining[range.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
        }

        // Extract "Who's there?"
        if let range = remaining.range(of: "Who's there", options: .caseInsensitive) {
            lines.append("Who's there?")
            remaining = String(remaining[range.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
        }

        // The rest is the answer (the name/thing)
        if !remaining.isEmpty {
            // Capitalize first letter
            let answer = remaining.prefix(1).uppercased() + remaining.dropFirst()
            lines.append(answer + ".")
        }

        return lines.isEmpty ? [joke.setup] : lines
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
                    userRating: 4
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )
        }
}

#Preview("Knock-Knock") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            JokeDetailSheet(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock knock. Who's there? Lettuce.",
                    punchline: "Lettuce who? Lettuce in, it's cold out here!",
                    userRating: 3
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )
        }
}
