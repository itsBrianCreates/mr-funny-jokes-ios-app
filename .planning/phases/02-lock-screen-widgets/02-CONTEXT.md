# Phase 2: Lock Screen Widgets - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Add lock screen widget support for all three accessory families (circular, rectangular, inline), displaying Joke of the Day content. Uses existing JokeOfTheDayWidget extension — add accessory families to configuration.

</domain>

<decisions>
## Implementation Decisions

### Content layout
- **Circular widget:** Display character avatar only (instantly recognizable)
- **Rectangular widget:** Show setup text + character name (e.g., "Mr. Funny" + "Why did the chicken...")
- **Inline widget:** Show character + setup in format "Mr. Funny: Why did the..."
- All three widget sizes display the same Joke of the Day (content stays in sync)

### Truncation strategy
- Use ellipsis truncation when text is too long for the widget
- Same ellipsis approach for all widget types (including inline)
- Always show full character names ("Mr. Funny", not "Mr. F")
- When space is limited, character name takes priority — truncate joke text first

### Visual style
- Use original character avatars, let iOS apply vibrant mode rendering (system tint)
- Transparent background — content sits directly on lock screen wallpaper
- Use iOS system default widget typography
- Unified visual treatment across all characters (no per-character styling)

### Tap behavior
- Tapping any lock screen widget launches app to home tab where Joke of the Day is displayed

### Claude's Discretion
- Exact character limits per widget type
- How to handle `.widgetRenderingMode` environment value
- Timeline refresh strategy (shares provider with home screen widgets)
- Deep link URL scheme implementation details

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard iOS widget patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-lock-screen-widgets*
*Context gathered: 2026-01-24*
