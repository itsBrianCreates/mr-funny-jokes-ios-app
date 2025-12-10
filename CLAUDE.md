# Mr. Funny Jokes - Claude Code Configuration

## Project Overview
Mr. Funny Jokes is an iOS app featuring joke content delivered by different character personas. This document provides instructions for Claude Code to process and manage jokes in the Firebase Firestore database.

---

## Joke Processing Skill

When the user provides jokes (via text, images, or URLs), follow this workflow:

### Step 1: Extract and Parse Jokes
- Parse all jokes from the provided input
- Combine setup and punchline into a single `text` field **with `\n` (newline) between them**
- Handle various formats: Q&A, knock-knock, one-liners, pickup lines

**IMPORTANT - Card Preview Formatting:**
The iOS app splits the `text` field to show a preview (setup) on the card, revealing the punchline when tapped. The parser looks for these delimiters in order: `\n\n`, `\n`, ` - `, `? `, `! `

- **Always use `\n`** between setup and punchline for reliable splitting
- Q&A jokes with `?` work automatically, but `\n` is still preferred for consistency
- Statement-style jokes (no `?`) **require `\n`** or they won't have a reveal

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
  text: string,             // Setup + \n + punchline (e.g., "Setup here.\nPunchline here.")
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

### Example Joke Objects
```javascript
// Q&A format - use \n after the question for consistent parsing
{
  "character": "mr_funny",
  "text": "Why don't scientists trust atoms?\nBecause they make up everything!",
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

// Statement format - \n is REQUIRED for card preview to work
{
  "character": "mr_bad",
  "text": "My parents raised me as an only child.\nMade my sister really mad.",
  "type": "dad_joke",
  "tags": ["family"],
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
4. I have a stepladder. Because my real ladder left when I was 5.
```

**Processing:**
1. Parse 4 jokes from input
2. Format text with `\n` between setup and punchline:
   - `"Why did the scarecrow win an award?\nBecause he was outstanding in his field!"`
   - `"Knock knock. Who's there? Boo. Boo who?\nDon't cry, it's just a joke!"`
   - `"Are you a magician?\nBecause whenever I look at you, everyone else disappears."`
   - `"I have a stepladder.\nBecause my real ladder left when I was 5."` ← statement joke, `\n` required!
3. Categorize:
   - Joke 1: `character: "mr_funny"`, `type: "dad_joke"`, `tags: ["work", "wordplay"]`
   - Joke 2: `character: "mr_funny"`, `type: "knock_knock"`, `tags: ["wordplay"]`
   - Joke 3: `character: "mr_love"`, `type: "pickup_line"`, `tags: ["wordplay"]`
   - Joke 4: `character: "mr_bad"`, `type: "dad_joke"`, `tags: ["family", "wordplay"]`
4. Run duplicate check against Firestore
5. Update `JOKES_TO_ADD` array in `scripts/add-jokes.js`
6. Run script: `node add-jokes.js`

**Report:**
```
X jokes added, Y duplicates skipped
- Added: "Why did the scarecrow..."
- Added: "Knock knock. Who's there? Boo..."
- Skipped (duplicate): "Are you a magician..."
- Added: "I have a stepladder..."
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
