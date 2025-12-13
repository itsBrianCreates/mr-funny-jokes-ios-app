import SwiftUI

/// A section showing "Weekly Top Ten" header with chevron and two category cards below
struct WeeklyTopTenCarouselView: View {
    @ObservedObject var viewModel: WeeklyRankingsViewModel
    let onCardTap: (RankingType) -> Void

    /// Fallback date range for current week when no data exists
    private var currentWeekDateRange: String {
        let calendar = Calendar(identifier: .iso8601)
        var easternCalendar = calendar
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        let now = Date()
        guard let weekInterval = easternCalendar.dateInterval(of: .weekOfYear, for: now) else {
            return "This Week"
        }

        let startMonth = easternCalendar.component(.month, from: weekInterval.start)
        let endMonth = easternCalendar.component(.month, from: weekInterval.end)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        let startMonthStr = monthFormatter.string(from: weekInterval.start)
        let startDayStr = dayFormatter.string(from: weekInterval.start)
        let endDayStr = dayFormatter.string(from: weekInterval.end.addingTimeInterval(-1))

        if startMonth == endMonth {
            return "\(startMonthStr) \(startDayStr) - \(endDayStr)"
        } else {
            let endMonthStr = monthFormatter.string(from: weekInterval.end)
            return "\(startMonthStr) \(startDayStr) - \(endMonthStr) \(endDayStr)"
        }
    }

    /// Computed date range that uses viewModel data or fallback
    private var dateRange: String {
        viewModel.weekDateRange.isEmpty ? currentWeekDateRange : viewModel.weekDateRange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with title and chevron
            WeeklyTopTenHeader(dateRange: dateRange) {
                HapticManager.shared.mediumImpact()
                onCardTap(.hilarious) // Default to hilarious when tapping header
            }

            // Two cards side by side
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    WeeklyTopTenCardSkeleton()
                    WeeklyTopTenCardSkeleton()
                } else {
                    WeeklyTopTenCard(
                        type: .hilarious,
                        totalRatings: viewModel.totalHilariousRatings,
                        hasData: viewModel.hasDataFor(type: .hilarious)
                    )
                    .onTapGesture {
                        HapticManager.shared.mediumImpact()
                        onCardTap(.hilarious)
                    }

                    WeeklyTopTenCard(
                        type: .horrible,
                        totalRatings: viewModel.totalHorribleRatings,
                        hasData: viewModel.hasDataFor(type: .horrible)
                    )
                    .onTapGesture {
                        HapticManager.shared.mediumImpact()
                        onCardTap(.horrible)
                    }
                }
            }
        }
    }
}

// MARK: - Header with Chevron

struct WeeklyTopTenHeader: View {
    let dateRange: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("Weekly Top Ten")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(dateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weekly Top Ten Card

/// A compact card for Hilarious or Horrible category - Apple Music editorial style
struct WeeklyTopTenCard: View {
    let type: RankingType
    let totalRatings: Int
    let hasData: Bool

    /// Gradient colors based on type (Apple Music editorial style - lighter top, darker bottom)
    private var gradientColors: [Color] {
        switch type {
        case .hilarious:
            return [
                Color(red: 1.0, green: 0.65, blue: 0.2),   // Bright orange/gold top
                Color(red: 0.75, green: 0.35, blue: 0.05) // Deep burnt orange bottom
            ]
        case .horrible:
            return [
                Color(red: 0.85, green: 0.25, blue: 0.4),  // Bright rose/magenta top
                Color(red: 0.55, green: 0.1, blue: 0.2)   // Deep burgundy bottom
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Emoji
            Text(type.emoji)
                .font(.system(size: 32))

            Spacer()

            // Title
            Text(type.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            // Subtitle - rating count or status
            if hasData && totalRatings > 0 {
                Text("\(totalRatings) ratings")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 120)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Skeleton Loader

struct WeeklyTopTenCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Emoji skeleton
            SkeletonShape(width: 32, height: 32, cornerRadius: 8)

            Spacer()

            // Title skeleton
            SkeletonShape(width: 80, height: 18, cornerRadius: 4)

            // Subtitle skeleton
            SkeletonShape(width: 60, height: 14, cornerRadius: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 120)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Full carousel view
        WeeklyTopTenCarouselView(
            viewModel: {
                let vm = WeeklyRankingsViewModel()
                return vm
            }(),
            onCardTap: { type in
                print("Tapped: \(type)")
            }
        )
        .padding(.horizontal)

        Divider()

        // Skeleton state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Top Ten")
                    .font(.title2.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                WeeklyTopTenCardSkeleton()
                WeeklyTopTenCardSkeleton()
            }
        }
        .padding(.horizontal)

        Divider()

        // Individual cards with data
        VStack(alignment: .leading, spacing: 12) {
            WeeklyTopTenHeader(dateRange: "Dec 9 - 15") {}

            HStack(spacing: 12) {
                WeeklyTopTenCard(
                    type: .hilarious,
                    totalRatings: 2847,
                    hasData: true
                )

                WeeklyTopTenCard(
                    type: .horrible,
                    totalRatings: 1523,
                    hasData: true
                )
            }
        }
        .padding(.horizontal)

        Spacer()
    }
    .padding(.top)
}
