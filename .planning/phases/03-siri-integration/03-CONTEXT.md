# Phase 3: Siri Integration - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Voice-activated joke delivery via App Intents. Users say "Hey Siri, tell me a joke from Mr. Funny Jokes" and Siri speaks the joke without opening the app. Works offline using cached jokes from SharedStorageService.

</domain>

<decisions>
## Implementation Decisions

### Spoken response style
- Natural pause between setup and punchline (like a comedian's timing)
- Include character intro: "Here's one from Mr. Potty: Why did..."
- Brief sign-off after punchline (e.g., "Want another?")
- Knock-knock jokes use full format with pauses: "Knock knock... who's there?... Boo... Boo who?..."

### Joke selection logic
- Random joke from cached collection (not Joke of the Day)
- Pull from all characters, not just Mr. Funny
- Track recently told jokes to avoid immediate repeats
- Friendly error if no cached jokes: "I don't have any jokes cached right now. Open the app to load some!"

### Visual snippet UI
- Display character avatar (use character bio images from Home tab — circle images)
- Show character name and full joke text
- No explicit app branding needed — character branding is sufficient
- Tapping snippet opens app and navigates to that specific joke

### Shortcut phrasing
- Primary phrase: "Tell me a joke from Mr. Funny Jokes"
- Support 2-3 phrase variations (e.g., "Tell me a joke", "Give me a joke")
- Shortcut name in Shortcuts app: "Tell Me a Joke"
- Expose intent for user composition — users can build custom shortcuts with it

### Claude's Discretion
- Exact pause timing for dramatic effect
- Specific phrase variations beyond primary
- Error state wording and tone
- Deep link implementation for tap-to-joke navigation

</decisions>

<specifics>
## Specific Ideas

- Use the character bio images from the Home tab for avatar display (circular images)
- Knock-knock jokes should feel interactive even though Siri is doing both parts
- Sign-off should be inviting but not pushy

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-siri-integration*
*Context gathered: 2026-01-24*
