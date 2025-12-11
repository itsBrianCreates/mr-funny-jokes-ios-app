/**
 * Add Videos to Firestore + Firebase Storage Script
 *
 * Uploads video files to Firebase Storage and adds metadata to Firestore.
 *
 * Usage:
 *   node add-videos.js                 # Add videos (with duplicate check)
 *   node add-videos.js --dry-run       # Simulate without making changes
 *   node add-videos.js --force         # Skip duplicate check (not recommended)
 *   node add-videos.js --metadata-only # Only add Firestore metadata (skip upload)
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 *   - Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
 *   - Video files in ./videos/ directory (or specify full path)
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { readFileSync, existsSync, statSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join, basename } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const COLLECTION_NAME = 'videos';
const STORAGE_BUCKET = 'mr-funny-jokes.firebasestorage.app';
const STORAGE_PATH = 'videos'; // Folder in Firebase Storage
const BATCH_SIZE = 500; // Firestore batch limit is 500
const FIREBASE_PROJECT_ID = 'mr-funny-jokes';

// Parse command line arguments
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const FORCE = args.includes('--force');
const METADATA_ONLY = args.includes('--metadata-only');

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};

/**
 * Videos to add
 *
 * Each video object should have:
 * - localPath: Path to the MP4 file (relative to scripts/ or absolute)
 * - character: "mr_funny" | "mr_potty" | "mr_bad" | "mr_love" | "mr_sad"
 * - title: Short title for the video
 * - description: Optional description
 * - tags: Array of 1-3 tags
 *
 * The script will:
 * 1. Upload the video to Firebase Storage
 * 2. Generate the public URL
 * 3. Create a Firestore document with all metadata
 */
const VIDEOS_TO_ADD = [
  {
    localPath: "./videos/Dad Joke Draw Blood Final.mp4",
    character: "mr_funny",
    title: "Dad Jokes That Draw Blood",
    description: "These jokes are so sharp they might hurt",
    tags: ["wordplay"],
    duration: 0  // Will play fine without exact duration
  },
];

/**
 * Initialize Firebase Admin SDK
 */
function initializeFirebase() {
  log.info('Initializing Firebase Admin SDK...');

  // Try to load service account from file
  const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');

  if (existsSync(serviceAccountPath)) {
    log.info(`Loading service account from: ${serviceAccountPath}`);
    const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

    initializeApp({
      credential: cert(serviceAccount),
      storageBucket: STORAGE_BUCKET
    });

    log.info(`Connected to project: ${serviceAccount.project_id}`);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    log.info(`Using GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS}`);
    initializeApp({
      storageBucket: STORAGE_BUCKET
    });
  } else {
    // Try Application Default Credentials (ADC) for cloud environments
    log.info('Attempting to use Application Default Credentials...');
    try {
      initializeApp({
        projectId: FIREBASE_PROJECT_ID,
        storageBucket: STORAGE_BUCKET
      });
      log.info(`Successfully initialized with Application Default Credentials for project: ${FIREBASE_PROJECT_ID}`);
    } catch (adcError) {
      throw new Error(
        'No Firebase credentials found!\n' +
        'Please either:\n' +
        '  1. Place serviceAccountKey.json in the scripts/ directory\n' +
        '  2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable\n\n' +
        'To get a service account key:\n' +
        '  1. Go to Firebase Console > Project Settings > Service Accounts\n' +
        '  2. Click "Generate new private key"\n' +
        '  3. Save the JSON file as scripts/serviceAccountKey.json'
      );
    }
  }

  return {
    db: getFirestore(),
    storage: getStorage().bucket()
  };
}

/**
 * Upload video file to Firebase Storage
 * @returns {Promise<string>} Public URL of the uploaded video
 */
async function uploadVideoToStorage(bucket, localPath, character) {
  const fileName = basename(localPath);
  const storagePath = `${STORAGE_PATH}/${character}/${fileName}`;

  log.info(`  Uploading: ${fileName} -> ${storagePath}`);

  // Check if file exists
  const fullPath = localPath.startsWith('/') ? localPath : join(__dirname, localPath);
  if (!existsSync(fullPath)) {
    throw new Error(`Video file not found: ${fullPath}`);
  }

  const fileStats = statSync(fullPath);
  log.info(`  File size: ${(fileStats.size / 1024 / 1024).toFixed(2)} MB`);

  if (DRY_RUN) {
    log.info(`  [DRY RUN] Would upload to: ${storagePath}`);
    return `https://storage.googleapis.com/${STORAGE_BUCKET}/${storagePath}`;
  }

  // Upload file
  await bucket.upload(fullPath, {
    destination: storagePath,
    metadata: {
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000', // Cache for 1 year
    }
  });

  // Make the file publicly accessible
  const file = bucket.file(storagePath);
  await file.makePublic();

  // Return the public URL
  const publicUrl = `https://storage.googleapis.com/${STORAGE_BUCKET}/${storagePath}`;
  log.info(`  Uploaded successfully: ${publicUrl}`);

  return publicUrl;
}

/**
 * Fetch all existing video URLs for duplicate checking
 */
async function fetchExistingVideoUrls(db) {
  log.info(`Fetching existing videos from '${COLLECTION_NAME}' collection for duplicate check...`);

  const snapshot = await db.collection(COLLECTION_NAME).get();
  const existingUrls = new Set();
  const existingTitles = new Set();

  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.video_url) {
      existingUrls.add(data.video_url);
    }
    if (data.title) {
      existingTitles.add(data.title.toLowerCase().trim());
    }
  });

  log.info(`Found ${existingUrls.size} existing videos in the collection`);
  return { existingUrls, existingTitles };
}

/**
 * Check for duplicates and return non-duplicate videos
 */
function filterDuplicates(videosToAdd, existingUrls, existingTitles) {
  const newVideos = [];
  const duplicates = [];

  for (const video of videosToAdd) {
    const normalizedTitle = video.title.toLowerCase().trim();
    if (existingTitles.has(normalizedTitle)) {
      duplicates.push({ ...video, reason: 'title already exists' });
    } else {
      newVideos.push(video);
    }
  }

  return { newVideos, duplicates };
}

/**
 * Add videos to Firestore using batch writes
 */
async function addVideos(db, bucket, videos) {
  if (videos.length === 0) {
    log.info('No videos to add');
    return { added: 0 };
  }

  log.divider();
  log.info(`ADDING ${videos.length} VIDEOS TO FIREBASE`);
  log.divider();

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made');
  }

  const addedVideos = [];

  for (let i = 0; i < videos.length; i += BATCH_SIZE) {
    const batchVideos = videos.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const video of batchVideos) {
      // Upload video to Storage (unless metadata-only mode)
      let videoUrl = video.video_url; // Use pre-existing URL if provided

      if (!METADATA_ONLY && video.localPath && !videoUrl) {
        try {
          videoUrl = await uploadVideoToStorage(bucket, video.localPath, video.character);
        } catch (uploadError) {
          log.error(`Failed to upload ${video.localPath}: ${uploadError.message}`);
          continue;
        }
      }

      if (!videoUrl) {
        log.error(`No video URL for: ${video.title} - skipping`);
        continue;
      }

      // Create new document reference with auto-generated ID
      const newDocRef = db.collection(COLLECTION_NAME).doc();

      // Prepare the document data with server timestamps
      const videoData = {
        title: video.title,
        description: video.description || '',
        character: video.character,
        video_url: videoUrl,
        thumbnail_url: video.thumbnail_url || null, // Optional
        duration: video.duration || 0,
        tags: video.tags || [],
        likes: 0,
        views: 0,
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp()
      };

      if (!DRY_RUN) {
        batch.set(newDocRef, videoData);
      }

      addedVideos.push({
        id: newDocRef.id,
        title: video.title,
        url: videoUrl
      });

      log.info(`  Adding: ${newDocRef.id} - "${video.title}"`);
    }

    if (!DRY_RUN && addedVideos.length > 0) {
      await batch.commit();
      log.info(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1}`);
    }
  }

  log.success(`Added ${addedVideos.length} new videos`);

  return { added: addedVideos.length, videos: addedVideos };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('ADD VIDEOS TO FIREBASE SCRIPT');
  log.info(`Mode: ${DRY_RUN ? 'DRY RUN' : FORCE ? 'FORCE (skip duplicate check)' : METADATA_ONLY ? 'METADATA ONLY' : 'NORMAL'}`);
  log.info(`Videos to add: ${VIDEOS_TO_ADD.length}`);
  log.divider();

  if (VIDEOS_TO_ADD.length === 0) {
    log.warn('No videos configured in VIDEOS_TO_ADD array.');
    log.info('Edit this file and add video entries to the VIDEOS_TO_ADD array.');
    log.info('\nExample entry:');
    log.info(`{
  localPath: "./videos/my-video.mp4",
  character: "mr_funny",
  title: "My Funny Video",
  description: "A hilarious video",
  tags: ["wordplay", "animals"],
  duration: 30
}`);
    return;
  }

  try {
    // Initialize Firebase
    const { db, storage } = initializeFirebase();

    let videosToAdd = VIDEOS_TO_ADD;
    let duplicates = [];

    // Check for duplicates unless --force is used
    if (!FORCE) {
      const { existingUrls, existingTitles } = await fetchExistingVideoUrls(db);
      const filtered = filterDuplicates(VIDEOS_TO_ADD, existingUrls, existingTitles);
      videosToAdd = filtered.newVideos;
      duplicates = filtered.duplicates;

      if (duplicates.length > 0) {
        log.divider();
        log.warn(`DUPLICATES FOUND: ${duplicates.length} video(s) already exist in the database`);
        log.divider();
        for (const dup of duplicates) {
          log.warn(`  SKIPPING: "${dup.title}" (${dup.reason})`);
        }
      }
    }

    // Add non-duplicate videos
    const result = await addVideos(db, storage, videosToAdd);

    log.divider();
    log.success('OPERATION COMPLETE!');
    log.info(`  Total videos provided: ${VIDEOS_TO_ADD.length}`);
    log.info(`  Duplicates skipped: ${duplicates.length}`);
    log.info(`  New videos added: ${result.added}`);
    if (DRY_RUN) {
      log.warn('  This was a DRY RUN - no actual changes were made');
    }
    log.divider();

  } catch (error) {
    log.error(`Failed to add videos: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Run the script
main();
