# Elsewhere - Setup Instructions

## Phase 1 Setup

### 1. Add Firebase Dependencies

Add Firebase to your Xcode project:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select these products:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseCore`
4. Click **Add Package**

### 2. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Add an iOS app:
   - Bundle ID: Check your Xcode project's bundle identifier
   - App nickname: "Elsewhere"
4. Download `GoogleService-Info.plist`
5. Drag `GoogleService-Info.plist` into your Xcode project (make sure "Copy items if needed" is checked)

### 3. Enable Firebase Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Authentication** in the left sidebar
4. Click the orange **"Get started"** button
5. You'll see the Authentication dashboard
6. Click on the **"Sign-in method"** tab at the top
7. Find **"Anonymous"** in the list of providers
8. Click on **"Anonymous"**
9. Toggle **"Enable"** to ON
10. Click **"Save"**

**Note:** Anonymous authentication allows users to sign in without providing credentials. This is perfect for Phase 1 MVP testing.

### 4. Configure OpenAI API Key

1. Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Add to `Info.plist`:

   - Open `Info.plist` in Xcode
   - Add new key: `OPENAI_API_KEY` (type: String)
   - Set value to your API key

   **OR** use environment variables:

   - Add to your scheme's environment variables
   - Key: `OPENAI_API_KEY`
   - Value: Your API key

### 5. Firestore Security Rules (Initial Setup)

**First, create your Firestore database:**

1. In Firebase Console, click the orange **"Create database"** button
2. **Step 1 - Select edition:**
   - Choose **"Standard edition"** (should be selected by default)
   - Click **"Next"**
3. **Step 2 - Database ID & location:**
   - Database ID: Leave as default (usually `(default)`)
   - Location: Select the closest region to you (e.g., `us-central1`, `us-east1`, `europe-west1`)
   - Click **"Next"**
4. **Step 3 - Configure:**
   - Choose **"Start in test mode"** (we'll add proper rules next)
   - Click **"Create"** or **"Enable"**
5. Wait for the database to be created (takes about 30 seconds)

**Now apply the security rules:**

I've created a `firestore.rules` file in your project root. Here's how to apply it:

1. After the database is created, you'll see tabs at the top: **Data**, **Rules**, **Indexes**, **Usage**
2. Click on the **Rules** tab
3. Copy the entire contents of `firestore.rules` file from your project
4. Paste it into the rules editor in Firebase Console (it will replace the default test mode rules)
5. Click **Publish**

**Option B: Using Firebase CLI (If you have it installed)**

```bash
# Install Firebase CLI if you haven't (requires Node.js)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

The security rules file is located at: `Elsewhere/firestore.rules`

### 6. Firestore Indexes

I've created a `firestore.indexes.json` file in your project root. Here's how to apply it:

**Option A: Using Firebase Console (Easiest)**

1. In Firebase Console, make sure you're in **Firestore Database**
2. After creating the database (from Step 4), you'll see tabs at the top
3. Click on the **Indexes** tab
4. Click **Create Index** button
5. Create the first index:
   - **Collection ID**: `chatMessages`
   - **Fields to index**:
     - Field: `houseId`, Order: `Ascending`
     - Field: `timestamp`, Order: `Ascending`
   - **Query scope**: Collection
   - Click **Create**
6. Create the second index:
   - **Collection ID**: `houses`
   - **Fields to index**:
     - Field: `ownerIds`, Order: `Array`
     - Field: `isDeleted`, Order: `Ascending`
   - **Query scope**: Collection
   - Click **Create**

**Option B: Using Firebase CLI (If you have it installed)**

```bash
# Deploy indexes
firebase deploy --only firestore:indexes
```

**Note:** Indexes take a few minutes to build. You'll see a status indicator in the Firebase Console. The app will work, but queries may be slower until indexes are ready.

The indexes file is located at: `Elsewhere/firestore.indexes.json`

### 7. Build and Run

The app should now compile and run. You'll see:

- Chat interface (will use placeholder responses if OpenAI key is missing)
- House Profile tab

## Next Steps

- Add authentication UI (sign in/sign up)
- Add house creation/onboarding flow
- Test Firebase integration
- Test OpenAI integration
