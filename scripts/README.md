# Firebase Migration Scripts

Scripts for managing the Mr Funny Jokes Firestore database.

## Setup

1. Go to [Firebase Console](https://console.firebase.google.com/) > Your Project > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Save the downloaded JSON file as `scripts/serviceAccountKey.json`

**Note:** Never commit `serviceAccountKey.json` to git - it's already in `.gitignore`

## Available Scripts

### Full Migration
```bash
cd scripts
npm run migrate
```

Migrates all category-based joke IDs (bad_001, dad_001, etc.) to auto-generated Firestore IDs.

### Backup Only
```bash
npm run backup
```

Creates a JSON backup of all jokes without making any changes.

### Verify Only
```bash
npm run verify
```

Shows current state of the collection without making changes.

### Dry Run
```bash
node migrate-joke-ids.js --dry-run
```

Simulates the full migration without making any actual changes.

## What the Migration Does

1. **Backup**: Creates a timestamped JSON backup of all jokes
2. **Create**: Creates new documents with auto-generated Firestore IDs
3. **Add Fields**:
   - `migrated_from`: Original document ID (for reference)
   - `updated_at`: Migration timestamp
4. **Fix**: Corrects the skeleton joke categorization (mr_bad -> mr_funny)
5. **Verify**: Confirms all new documents were created correctly
6. **Delete**: Removes old category-based documents
7. **Log**: Saves a migration log with old->new ID mappings

## Safety Features

- Always creates backup before any modifications
- Verifies document counts before and after
- Uses batched operations for data integrity
- Provides dry-run mode for testing
- Detailed logging throughout the process
