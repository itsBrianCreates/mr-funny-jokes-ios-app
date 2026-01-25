# Phase 1: Foundation & Cleanup - Research

**Researched:** 2026-01-24
**Domain:** iOS/SwiftUI Configuration & Native Patterns
**Confidence:** HIGH

## Summary

This phase involves three distinct technical domains: removing iPad support from the Xcode project, changing rankings from weekly to monthly calculations, and simplifying the notification settings UI. All three are well-understood iOS development tasks with clear implementation paths.

The codebase is already iPhone-only in the Xcode configuration (`TARGETED_DEVICE_FAMILY = 1`), so iPad removal is primarily a verification task with potential cleanup of any iPad-specific assets. The rankings change is a straightforward rename and data model update. The notification UI change involves removing the DatePicker time selector and adding a deep-link button to iOS Settings.

**Primary recommendation:** Use native SwiftUI components exclusively. The existing codebase already follows good SwiftUI patterns - extend these patterns for the notification settings changes.

## Standard Stack

This phase uses only native iOS frameworks - no new dependencies required.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI Framework | Native Apple framework, already in use |
| UIKit | iOS 17+ | Settings deep link | Required for `UIApplication.openNotificationSettingsURLString` |
| UserNotifications | iOS 17+ | Notification management | Already in use via `NotificationManager` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Firebase Firestore | 12.6.0+ | Backend data | Already in use, no changes needed for this phase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `openNotificationSettingsURLString` (iOS 16+) | `openSettingsURLString` (iOS 8+) | openSettingsURLString opens general app settings, not notification-specific settings |

**Installation:**
No new dependencies required - all frameworks already in the project.

## Architecture Patterns

### Current Project Structure (No Changes Needed)
```
MrFunnyJokes/
├── App/                 # App entry point
├── Models/              # Data models (Joke, FirestoreModels)
├── Views/               # SwiftUI views
│   ├── WeeklyTopTen/    # Rankings views - RENAME to MonthlyTopTen
│   └── SettingsView.swift # Notification settings - MODIFY
├── ViewModels/          # View models
│   └── WeeklyRankingsViewModel.swift # RENAME to MonthlyRankingsViewModel
├── Services/            # Business logic
│   └── NotificationManager.swift # Keep time properties, remove from UI
└── Utilities/           # Helpers
```

### Pattern 1: Settings Deep Link Button
**What:** Native SwiftUI Button that opens iOS Settings notification page
**When to use:** When guiding users to iOS-level settings for the app
**Example:**
```swift
// Source: Apple Developer Documentation - UIApplication.openNotificationSettingsURLString
Button {
    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
    }
} label: {
    HStack {
        Text("Manage in Settings")
        Spacer()
        Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

### Pattern 2: Helper Text with Friendly Tone
**What:** Footer text in List Section guiding users
**When to use:** When explaining where to adjust settings
**Example:**
```swift
// Native SwiftUI Section with footer
Section {
    // Toggle and button content
} header: {
    Text("Notifications")
} footer: {
    Text("Want to adjust when you get jokes? Tap above to manage your notification preferences in Settings.")
}
```

### Pattern 3: Xcode Build Settings for iPhone-Only
**What:** Configuration to restrict app to iPhone devices
**When to use:** When removing iPad support
**Example:**
```
// In project.pbxproj or Xcode Build Settings
TARGETED_DEVICE_FAMILY = 1;  // 1 = iPhone only, 2 = iPad only, 1,2 = Universal
```

### Anti-Patterns to Avoid
- **Private URL schemes for Settings:** Do not use `App-prefs:root=...` URLs - these are private APIs and will cause App Store rejection
- **Manually parsing project.pbxproj:** Use Xcode UI or xcodeproj Ruby gem, not manual text editing
- **Custom notification time picker:** The user has decided to remove this - use iOS Settings instead

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Settings deep link | Custom URL scheme parsing | `UIApplication.openNotificationSettingsURLString` | Apple's official API, guaranteed to work |
| Date range formatting | Custom string manipulation | `DateFormatter` with `.dateStyle` | Handles localization automatically |
| Device family detection | Runtime checks | Build settings `TARGETED_DEVICE_FAMILY` | Compile-time exclusion is cleaner |

**Key insight:** All tasks in this phase have native solutions. No custom implementations are needed - just configuration changes and using existing APIs.

## Common Pitfalls

### Pitfall 1: Using Wrong Settings URL
**What goes wrong:** Opening general settings instead of notification settings
**Why it happens:** Confusing `openSettingsURLString` (iOS 8+) with `openNotificationSettingsURLString` (iOS 16+)
**How to avoid:** Use `UIApplication.openNotificationSettingsURLString` explicitly
**Warning signs:** Users land on general app settings page, not notifications

### Pitfall 2: Forgetting to Update All "Weekly" References
**What goes wrong:** Inconsistent UI shows "Weekly" in some places, "Monthly" in others
**Why it happens:** Multiple files contain the word "Weekly" - easy to miss some
**How to avoid:** Use project-wide search for "weekly" (case-insensitive), update all occurrences
**Warning signs:** Visual inconsistency in UI, code review catches naming mismatches

Files to check:
- `WeeklyTopTenCarouselView.swift` - struct name, header text
- `WeeklyTopTenDetailView.swift` - struct name, navigation title
- `WeeklyRankingsViewModel.swift` - class name, properties like `weekDateRange`
- `FirestoreService.swift` - collection name `weekly_rankings` (may need backend coordination)
- `FirestoreModels.swift` - `WeeklyRankings` struct

### Pitfall 3: Not Removing NotificationManager Time Properties
**What goes wrong:** Leaving unused code in NotificationManager that manages time selection
**Why it happens:** Only UI is removed, backend properties forgotten
**How to avoid:** Keep `notificationHour` and `notificationMinute` properties - they're still used for scheduling. Only remove the UI for selecting them.
**Warning signs:** Unnecessary code complexity

### Pitfall 4: iPad Assets Left Behind
**What goes wrong:** App bundle includes unused iPad-specific assets
**Why it happens:** Assets.xcassets may contain iPad-specific image sets
**How to avoid:** Audit Assets.xcassets for iPad-specific images, remove them
**Warning signs:** Larger app bundle size than necessary

### Pitfall 5: Widget Extension iPad Support
**What goes wrong:** Widget still targets iPad
**Why it happens:** Widget extension has separate build settings
**How to avoid:** Set `TARGETED_DEVICE_FAMILY = 1` for JokeOfTheDayWidgetExtension target too
**Warning signs:** Widget appears on iPad even though main app doesn't

## Code Examples

### Opening Notification Settings (iOS 16+)
```swift
// Source: Apple Developer Documentation
// UIApplication.openNotificationSettingsURLString requires iOS 16.0+
// This app targets iOS 17+, so no availability check needed

Button {
    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
    }
} label: {
    Label("Open Notification Settings", systemImage: "gear")
}
```

### Updated Notification Section (Complete Example)
```swift
// Source: Existing SettingsView.swift pattern + Apple HIG
private var notificationSection: some View {
    Section {
        // Main toggle - KEEP
        Toggle(isOn: $notificationManager.notificationsEnabled) {
            Label {
                Text("Daily Joke Reminder")
            } icon: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.accessibleYellow)
            }
        }
        .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
            if newValue && !notificationManager.isAuthorized {
                requestPermission()
            }
        }

        // TIME PICKER REMOVED - Replace with Settings button
        if notificationManager.notificationsEnabled {
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Label {
                        Text("Manage Notifications")
                    } icon: {
                        Image(systemName: "gear")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        }

        // Permission warning - KEEP (slightly modified)
        if notificationManager.notificationsEnabled && !notificationManager.isAuthorized {
            // ... existing warning code stays the same
        }
    } header: {
        Text("Notifications")
    } footer: {
        Text("Want to adjust when you get jokes? Head to Settings!")
    }
}
```

### Monthly Rankings Header
```swift
// Source: Existing WeeklyTop10Header pattern
struct MonthlyTop10Header: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("Monthly Top 10")  // Changed from "Weekly Top 10"
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.leading, 2)
        }
        .buttonStyle(.plain)
    }
}
```

### Xcode Build Settings Verification
```
// These settings should already be present - VERIFY they are set correctly
// For BOTH MrFunnyJokes target AND JokeOfTheDayWidgetExtension target:

TARGETED_DEVICE_FAMILY = 1
// 1 = iPhone only (correct)
// 2 = iPad only
// 1,2 = Universal (wrong for this project)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `openSettingsURLString` | `openNotificationSettingsURLString` | iOS 16 (2022) | Direct link to notification settings |
| Universal apps by default | Explicit device family selection | Xcode 14+ | Clearer build configuration |
| UIKit Settings bundle | SwiftUI @AppStorage + Settings link | iOS 14+ | Simpler settings management |

**Deprecated/outdated:**
- `UIApplication.shared.openURL(_:)` - Use `open(_:options:completionHandler:)` instead (deprecated iOS 10)
- Private URL schemes (`App-prefs:`) - Never officially supported, will cause rejection

## Open Questions

### 1. Firebase Collection Naming
- **What we know:** Current collection is named `weekly_rankings` in Firestore
- **What's unclear:** Whether to rename to `monthly_rankings` or keep existing name
- **Recommendation:** Keep `weekly_rankings` collection name to avoid backend changes. The collection name is an implementation detail; only UI-facing labels need to change to "Monthly."

### 2. Backend Aggregation Script
- **What we know:** Rankings are computed server-side and stored in Firestore
- **What's unclear:** Whether a backend script change is needed for 30-day window
- **Recommendation:** This is outside Phase 1 scope if backend changes are required. The UI can display "Monthly" while data comes from existing `weekly_rankings` collection during transition. Add backend task if needed.

### 3. Helper Text Exact Wording
- **What we know:** User wants "friendly tone" (e.g., "Want to adjust when you get jokes? Head to Settings!")
- **What's unclear:** Final copy not specified
- **Recommendation:** Use the example provided in CONTEXT.md as starting point. Finalize during implementation.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - `UIApplication.openNotificationSettingsURLString` (iOS 16+)
- Apple Developer Documentation - `UIApplication.openSettingsURLString` (iOS 8+)
- Xcode project.pbxproj analysis - Current `TARGETED_DEVICE_FAMILY = 1` confirmed
- Existing codebase - SettingsView.swift, WeeklyRankingsViewModel.swift, NotificationManager.swift

### Secondary (MEDIUM confidence)
- [Apple Developer Forums - Opening Settings](https://developer.apple.com/forums/thread/717468)
- [Apple Developer Forums - Remove iPad Support](https://developer.apple.com/forums/thread/701706)
- [How to restrict iOS app to iPhone only](https://www.codestudy.net/blog/how-to-restrict-the-ios-app-only-for-iphone-excluding-ipad/)

### Tertiary (LOW confidence)
- None - all findings verified with official documentation or codebase analysis

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Native frameworks only, already in use
- Architecture: HIGH - Minimal changes to existing patterns
- Pitfalls: HIGH - Well-documented iOS development patterns
- Code examples: HIGH - Verified against Apple docs and existing codebase

**Research date:** 2026-01-24
**Valid until:** 2026-02-24 (30 days - stable iOS APIs)

---

## Implementation Checklist (for Planner)

### iPad Removal
- [ ] Verify `TARGETED_DEVICE_FAMILY = 1` in MrFunnyJokes target
- [ ] Verify `TARGETED_DEVICE_FAMILY = 1` in JokeOfTheDayWidgetExtension target
- [ ] Audit Assets.xcassets for iPad-specific images
- [ ] Remove any iPad-specific code if found
- [ ] Clean build folder and test on iPhone simulator

### Rankings Weekly -> Monthly
- [ ] Rename `WeeklyRankingsViewModel` -> `MonthlyRankingsViewModel`
- [ ] Rename `WeeklyTopTenCarouselView` -> `MonthlyTopTenCarouselView`
- [ ] Rename `WeeklyTopTenDetailView` -> `MonthlyTopTenDetailView`
- [ ] Update `WeeklyTop10Header` -> `MonthlyTop10Header`
- [ ] Change all UI text from "Weekly" to "Monthly"
- [ ] Update `weekDateRange` property name to `monthDateRange`
- [ ] Update date range formatting for monthly display
- [ ] Keep Firestore collection name `weekly_rankings` (no backend changes)

### Notification UI Simplification
- [ ] Remove DatePicker from SettingsView.swift
- [ ] Remove `showingTimePicker` state variable
- [ ] Add "Manage Notifications" button with Settings deep link
- [ ] Use `UIApplication.openNotificationSettingsURLString`
- [ ] Update Section footer with friendly helper text
- [ ] Keep on/off toggle functional
- [ ] Keep permission warning functional
- [ ] Keep NotificationManager time properties (used for scheduling)
