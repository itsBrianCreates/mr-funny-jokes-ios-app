# Mr. Funny Jokes - Claude Code Configuration

## Project Overview
Mr. Funny Jokes is an iOS app featuring joke content delivered by different character personas. This document provides instructions for Claude Code to process and manage jokes in the Firebase Firestore database.

---

## SwiftUI Development Guidelines

### Use Native iOS Components
Always prefer native SwiftUI/UIKit components over custom implementations:

- **Segmented controls**: Use `Picker` with `.pickerStyle(.segmented)` instead of custom tab selectors
- **Navigation**: Use `NavigationStack`, `NavigationLink`, and `.navigationDestination`
- **Lists**: Use `List` for standard scrollable content with selection
- **Buttons**: Use `Button` with standard button styles (`.bordered`, `.borderedProminent`, etc.)
- **Text fields**: Use `TextField` and `SecureField`
- **Toggles**: Use `Toggle` instead of custom switches
- **Alerts/Sheets**: Use `.alert()` and `.sheet()` modifiers
- **Menus**: Use `Menu` for contextual actions

### Why Native Components?
- Consistent iOS look and feel
- Built-in accessibility support
- Automatic dark mode adaptation
- System haptics and animations
- Future-proof with iOS updates

### When Custom Components Are OK
- When native components don't support the required design (e.g., custom card layouts)
- For branded visual elements (e.g., gradient cards, character avatars)
- When performance requires optimization beyond native capabilities

---

## Joke Processing Skill

When the user provides jokes (via text, images, or URLs), follow this workflow:

### Step 1: Extract and Parse Jokes
- Parse all jokes from the provided input
- Separate setup and punchline into a single `text` field
- Handle various formats: Q&A, knock-knock, one-liners, pickup lines

### Step 2: Categorize Each Joke

#### Character Field (Content Theme)
Assign based on joke content/theme:

| Character | Value | Assign When Content Includes |
|-----------|-------|------------------------------|
| Mr. Funny | `mr_funny` | Puns, wordplay, wholesome humor **(default)** |
| Mr. Potty | `mr_potty` | Bathroom, toilet, poop themes |
| Mr. Bad | `mr_bad` | Dark, morbid, edgy, dismissive/rude punchlines |
| Mr. Love | `mr_love` | Romance, flirting, attraction |
| Mr. Sad | `mr_sad` | Melancholy, self-deprecating, depressing |

#### Type Field (Joke Format)
Assign based on structure - **ONLY 3 OPTIONS**:

| Format | Value | Description |
|--------|-------|-------------|
| Knock-knock | `knock_knock` | Knock-knock structure |
| Pickup lines | `pickup_line` | Romantic openers/pickup lines |
| Everything else | `dad_joke` | Q&A, puns, one-liners, etc. |

**Important:** `type` is for format filtering in the app UI. `character` determines which persona's section displays the joke. These are independent - a knock-knock joke can belong to any character.

### Step 3: Generate Tags
Assign 1-3 tags from this list:
- `animals`, `food`, `work`, `school`, `sports`, `music`
- `technology`, `science`, `health`, `weather`, `holidays`
- `family`, `travel`, `wordplay`, `religious`

### Step 4: Check for Duplicates
Before inserting, query the `jokes` collection:
1. Fetch all existing joke texts
2. Normalize comparison (lowercase, trim whitespace)
3. Skip jokes that already exist
4. Report which jokes were skipped as duplicates

### Step 5: Insert via Batch Write
Use Firebase Admin SDK with batch writes (max 500 per batch):
1. Create document with auto-generated ID
2. Set all required fields with defaults
3. Use `FieldValue.serverTimestamp()` for timestamps
4. Commit batch and report results

---

## Firebase Schema

**Collection:** `jokes` (auto-generated document IDs)

```javascript
{
  character: string,        // "mr_funny" | "mr_potty" | "mr_bad" | "mr_love" | "mr_sad"
  text: string,             // Full joke text (setup + punchline combined)
  type: string,             // "dad_joke" | "knock_knock" | "pickup_line"
  tags: string[],           // 1-3 tags from allowed list
  sfw: boolean,             // Always true
  source: string,           // "classic" | "original" | "submitted"
  likes: number,            // Initialize to 0
  dislikes: number,         // Initialize to 0
  rating_sum: number,       // Initialize to 0
  rating_count: number,     // Initialize to 0
  rating_avg: number,       // Initialize to 0
  popularity_score: number, // Initialize to 0
  created_at: Timestamp,    // Server timestamp
  updated_at: Timestamp     // Server timestamp
}
```

---

## Default Values

| Field | Default Value |
|-------|---------------|
| `sfw` | `true` (always) |
| `source` | `"classic"` (unless specified) |
| `likes` | `0` |
| `dislikes` | `0` |
| `rating_sum` | `0` |
| `rating_count` | `0` |
| `rating_avg` | `0` |
| `popularity_score` | `0` |
| `created_at` | `FieldValue.serverTimestamp()` |
| `updated_at` | `FieldValue.serverTimestamp()` |

---

## Adding Jokes Workflow

### Using the Existing Script

The project has an `add-jokes.js` script in `scripts/` directory:

```bash
cd scripts
npm install                    # First time only
node add-jokes.js              # Add jokes with duplicate check
node add-jokes.js --dry-run    # Simulate without changes
node add-jokes.js --force      # Skip duplicate check
```

### Script Location
`scripts/add-jokes.js`

### To Add New Jokes
1. Edit the `JOKES_TO_ADD` array in `scripts/add-jokes.js`
2. Format each joke object following the schema
3. Run the script

### Example Joke Object
```javascript
{
  "character": "mr_funny",
  "text": "Why don't scientists trust atoms? Because they make up everything!",
  "type": "dad_joke",
  "tags": ["science", "wordplay"],
  "sfw": true,
  "source": "classic",
  "likes": 0,
  "dislikes": 0,
  "rating_sum": 0,
  "rating_count": 0,
  "rating_avg": 0,
  "popularity_score": 0
}
```

---

## Firebase Setup Requirements

### Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com/) > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Save as `scripts/serviceAccountKey.json`

**Note:** `serviceAccountKey.json` is in `.gitignore` - never commit it.

### Project Configuration
- **Project ID:** `mr-funny-jokes`
- **Collection:** `jokes`
- **Batch Size Limit:** 500 documents per batch

---

## Processing Example

When user says "add these jokes" followed by joke text:

**Input:**
```
Add these jokes:

1. Why did the scarecrow win an award? Because he was outstanding in his field!
2. Knock knock. Who's there? Boo. Boo who? Don't cry, it's just a joke!
3. Are you a magician? Because whenever I look at you, everyone else disappears.
```

**Processing:**
1. Parse 3 jokes from input
2. Categorize:
   - Joke 1: `character: "mr_funny"`, `type: "dad_joke"`, `tags: ["work", "wordplay"]`
   - Joke 2: `character: "mr_funny"`, `type: "knock_knock"`, `tags: ["wordplay"]`
   - Joke 3: `character: "mr_love"`, `type: "pickup_line"`, `tags: ["wordplay"]`
3. Run duplicate check against Firestore
4. Update `JOKES_TO_ADD` array in `scripts/add-jokes.js`
5. Run script: `node add-jokes.js`

**Report:**
```
X jokes added, Y duplicates skipped
- Added: "Why did the scarecrow..."
- Added: "Knock knock. Who's there? Boo..."
- Skipped (duplicate): "Are you a magician..."
```

---

## Quick Reference

### Valid Characters
`mr_funny`, `mr_potty`, `mr_bad`, `mr_love`, `mr_sad`

### Valid Types
`dad_joke`, `knock_knock`, `pickup_line`

### Valid Tags
`animals`, `food`, `work`, `school`, `sports`, `music`, `technology`, `science`, `health`, `weather`, `holidays`, `family`, `travel`, `wordplay`, `religious`

### Valid Sources
`classic`, `original`, `submitted`

<!-- CODESTORY-START -->
## CodeStory: Auto-Tracking & Trigger

### Live Session Tracking

While working on this project, automatically log notable moments to `.social-draft-Brian.md`:

**What to capture:**
- Technical wins (clever solutions, performance improvements, clean refactors)
- Progress milestones (features completed, bugs squashed, tests passing)
- Lessons learned (debugging adventures, "aha" moments, things that surprised you)
- Interesting decisions (architecture choices, tradeoffs you made, why you picked one approach over another)
- Frustrations turned victories (that bug that took forever, the docs that were wrong)

**Log format:**
```
## Session: {DATE}

{TIME} - Brief note about what just happened
- Include relevant code snippets or commands when they add context
- Keep it casual and authentic
- Write like you are telling a friend about your day
```

**Example entry:**
```
## Session: 2024-01-15

2:34 PM - Finally figured out why the auth was failing. Turns out the token was being URL-encoded twice. Classic.

3:15 PM - Refactored the entire validation layer. Went from 400 lines to 120. Sometimes less really is more.

4:02 PM - Added rate limiting. Used a sliding window approach instead of fixed buckets. Feels cleaner.
```

### Trigger Word

When the user says "CodeStory" in conversation (e.g., "run CodeStory", "let's do CodeStory", "time for CodeStory"), run the `/CodeStory` skill to generate social media content.
<!-- CODESTORY-END -->
