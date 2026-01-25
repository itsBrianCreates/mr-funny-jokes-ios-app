# Mr. Funny Jokes v1.0 - Test Checklist

**Purpose:** Comprehensive manual testing of all v1.0 features before App Store submission
**Device:** Physical iPhone (iOS 17+)
**Tester:** [Your name]
**Date:** [Testing date]

---

## Instructions

1. Work through each priority section in order (Priority 1 first)
2. Check off each test case as you complete it
3. If a test fails, use the bug reporting format at the bottom
4. Report bugs directly in chat for immediate resolution
5. After all tests pass, mark the section as COMPLETE

**Prerequisites:**
- Fresh install of the app (delete and reinstall recommended)
- Network connectivity for initial setup
- Shortcuts app installed (built-in iOS app)

---

## Severity Definitions

| Severity | Definition | Action |
|----------|------------|--------|
| **Blocking** | Crashes OR broken features | Must fix before release |
| **Cosmetic** | Visual issues, minor polish | Track for v1.1 backlog |

**Examples:**
- Blocking: App crashes, Siri fails to speak joke, widget shows no content
- Cosmetic: Text slightly cut off, minor spacing issue, color not quite right

---

## Priority 1: Siri Integration (Critical for App Review 4.2.2)

*This is the critical feature for App Store Guideline 4.2.2 compliance.*

### Initial Setup
- [ ] Open app and navigate to home tab
- [ ] Wait for jokes to load (populates Siri cache)
- [ ] Verify jokes display in the app

### Shortcuts App Testing
- [ ] Open Shortcuts app
- [ ] Search for "Mr. Funny"
- [ ] Verify "Tell Me a Joke" shortcut appears in search results
- [ ] Tap to run the shortcut
- [ ] Verify Siri speaks joke with character introduction
- [ ] Verify visual snippet shows character avatar and joke text

### Voice Command Testing
- [ ] Say: "Hey Siri, tell me a joke from Mr. Funny Jokes"
- [ ] Verify voice command triggers app intent (not Siri's built-in jokes)
- [ ] Verify Siri speaks a joke from the app
- [ ] Verify visual snippet appears

### Offline Testing (Airplane Mode)
- [ ] Enable Airplane Mode (Control Center > tap airplane icon)
- [ ] Open Shortcuts app
- [ ] Run "Tell Me a Joke" shortcut
- [ ] Verify Siri speaks a cached joke (offline mode works)
- [ ] Disable Airplane Mode

### Priority 1 Result
- [ ] **SECTION COMPLETE**

**Notes:** ________________________________________________

---

## Priority 2: Lock Screen Widgets

*Demonstrates native iOS integration depth.*

### Widget Gallery Access
- [ ] Lock device
- [ ] Long-press lock screen
- [ ] Tap "Customize"
- [ ] Select lock screen to edit
- [ ] Tap widget area to add widgets

### Circular Widget (accessoryCircular)
- [ ] Add circular widget to lock screen
- [ ] Verify widget appears in widget gallery
- [ ] Verify circular widget shows SF Symbol (face.smiling)
- [ ] Verify widget is visible and properly sized

### Rectangular Widget (accessoryRectangular)
- [ ] Add rectangular widget to lock screen
- [ ] Verify rectangular widget shows character name
- [ ] Verify rectangular widget shows joke text (truncated)
- [ ] Verify text is readable in vibrant mode

### Inline Widget (accessoryInline)
- [ ] Add inline widget to lock screen
- [ ] Verify inline widget shows joke text
- [ ] Verify text fits within the inline space

### Tap Behavior
- [ ] Tap any lock screen widget
- [ ] Verify app opens to home screen

### Vibrant Mode Testing
- [ ] Test with light wallpaper
- [ ] Test with dark wallpaper
- [ ] Verify widgets remain readable with both wallpapers

### Priority 2 Result
- [ ] **SECTION COMPLETE**

**Notes:** ________________________________________________

---

## Priority 3: Home Screen Widgets

*Visual polish verified in Phase 4.*

### Widget Gallery
- [ ] Long-press home screen
- [ ] Tap "+" to access widget gallery
- [ ] Search for "Joke of the Day"
- [ ] Verify widget appears in gallery with preview

### Small Widget
- [ ] Add small widget to home screen
- [ ] Verify small widget displays character avatar
- [ ] Verify small widget displays joke text
- [ ] Verify 8pt padding around content

### Medium Widget
- [ ] Add medium widget to home screen
- [ ] Verify medium widget displays character avatar
- [ ] Verify medium widget shows 2 lines of text (lineLimit)
- [ ] Verify 11pt padding around content

### Large Widget
- [ ] Add large widget to home screen
- [ ] Verify large widget displays full joke presentation
- [ ] Verify large widget shows character prominently
- [ ] Verify 11pt padding around content

### Dark Mode Testing
- [ ] Go to Settings > Display & Brightness > Dark
- [ ] Verify all widgets adapt to dark mode colors
- [ ] Verify text remains readable in dark mode
- [ ] Return to Light mode (or keep as preferred)

### Tap Behavior
- [ ] Tap small widget
- [ ] Verify app opens correctly
- [ ] Tap medium widget
- [ ] Verify app opens correctly
- [ ] Tap large widget
- [ ] Verify app opens correctly

### Priority 3 Result
- [ ] **SECTION COMPLETE**

**Notes:** ________________________________________________

---

## Priority 4: Settings & Notifications

*Settings simplification from Phase 1.*

### Settings Tab
- [ ] Open app
- [ ] Navigate to Settings tab
- [ ] Verify Settings screen loads without errors

### Notification Toggle
- [ ] Verify notification toggle is present
- [ ] If off, toggle notifications ON
- [ ] Verify toggle state persists after app restart
- [ ] Toggle notifications OFF
- [ ] Verify toggle state persists after app restart

### Manage Notifications Button
- [ ] Tap "Manage Notifications" button
- [ ] Verify iOS Settings app opens
- [ ] Verify it opens directly to Mr. Funny Jokes notification settings
- [ ] Return to app (tap back or swipe from edge)

### Siri Tip View
- [ ] Verify SiriTipView is visible in Settings
- [ ] Verify it shows Siri shortcut suggestion
- [ ] Tap SiriTipView
- [ ] Verify Shortcuts app opens

### Priority 4 Result
- [ ] **SECTION COMPLETE**

**Notes:** ________________________________________________

---

## Priority 5: Rankings

*Monthly rankings from Phase 1.*

### Rankings Display
- [ ] Open app
- [ ] Navigate to home tab
- [ ] Scroll to rankings section
- [ ] Verify section header says "Monthly Top 10" (NOT "Weekly")

### Rankings Content
- [ ] Verify top jokes display with ranking numbers
- [ ] Verify character avatars appear with each joke
- [ ] Verify joke text is readable

### Detail View
- [ ] Tap a ranked joke
- [ ] Verify detail view opens
- [ ] Verify detail view title shows "Monthly Top 10"
- [ ] Navigate back to home

### Priority 5 Result
- [ ] **SECTION COMPLETE**

**Notes:** ________________________________________________

---

## Bug Reporting Format

When you encounter a bug, report it using this format:

```
BUG: [Short description]
- Where: [Screen/feature]
- Steps: [How to reproduce]
- Expected: [What should happen]
- Actual: [What actually happened]
- Severity: [Blocking / Cosmetic]
```

**Example:**
```
BUG: Siri shortcut not appearing in Shortcuts app
- Where: Shortcuts app search
- Steps: Open Shortcuts, search "Mr. Funny"
- Expected: "Tell Me a Joke" shortcut appears
- Actual: No results found
- Severity: Blocking
```

---

## Test Completion Summary

| Priority | Section | Status | Bugs Found |
|----------|---------|--------|------------|
| 1 | Siri Integration | [ ] Pass / [ ] Fail | |
| 2 | Lock Screen Widgets | [ ] Pass / [ ] Fail | |
| 3 | Home Screen Widgets | [ ] Pass / [ ] Fail | |
| 4 | Settings & Notifications | [ ] Pass / [ ] Fail | |
| 5 | Rankings | [ ] Pass / [ ] Fail | |

**Total Test Cases:** 47
**Passed:** ___
**Failed:** ___
**Blocking Bugs:** ___
**Cosmetic Issues:** ___

---

## Final Checklist

- [ ] All 5 priority sections tested
- [ ] All blocking bugs fixed
- [ ] Cosmetic issues documented for v1.1
- [ ] App ready for content loading (Phase 6)
- [ ] App ready for App Store submission

**Testing Completed:** [ ] Yes / [ ] No
**Tested By:** _______________
**Date Completed:** _______________

---

*Test checklist generated: 2026-01-25*
*Phase: 05-testing-bug-fixes, Plan: 01*
