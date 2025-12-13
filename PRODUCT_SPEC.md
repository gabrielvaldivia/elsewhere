# Upstate Home Copilot - Product Specification

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Planning

---

## Table of Contents

1. [Overview](#overview)
2. [Target User](#target-user)
3. [Core Mental Model](#core-mental-model)
4. [App Structure](#app-structure)
5. [Technical Architecture](#technical-architecture)
6. [Data Models](#data-models)
7. [Features](#features)
8. [Onboarding Flow](#onboarding-flow)
9. [Non-Goals](#non-goals)
10. [Success Metrics](#success-metrics)

---

## Overview

### Purpose

Upstate Home Copilot is a lightweight operations app for people who own a second home and are not there full time. Its job is to help owners remember how their house works, coordinate the right vendors at the right time, and stay ahead of maintenance before it becomes stressful.

This is not property management software and not a smart home dashboard. It is a memory, coordination, and planning layer built around houses (users can manage multiple houses).

### Guiding Principle

The product succeeds if owners feel like:

> "Someone understands my house and is helping me stay ahead of it"

Not because the system is automated, but because it is attentive, grounded, and reliable.

---

## Target User

### Primary Users

Owners of a second home that is used personally, not rented. Typical patterns include:

- Living in a city and traveling to the house periodically
- Low or irregular occupancy
- System-heavy homes where failures can be quiet and expensive
- Owners who currently manage the house through notes, texts, and ad hoc reminders

### User Personas

**Primary Persona: "The Weekend Owner"**

- Lives in urban area, travels to second home 2-4 times per month
- House is 2-4 hours away
- Uses house seasonally (summer weekends, winter holidays)
- Manages maintenance through text messages and notes
- Wants to avoid emergency situations when arriving

**Secondary Persona: "The Remote Owner"**

- Lives far from second home (different state/region)
- Visits infrequently (monthly or less)
- Relies heavily on local vendors
- Needs coordination help across time zones
- Wants peace of mind about house condition

---

## Core Mental Model

The product is organized around three concepts:

1. **A house** that has systems, history, and ongoing needs
2. **An agent** that understands that house and helps coordinate work
3. **A small set of surfaces** where decisions and follow-through happen

The agent is the primary interface. Everything else exists to support memory, clarity, and action.

### Agent Personality

- Explicitly references what it knows about the house
- Comfortable with partial knowledge and uncertainty
- Messages feel timely and calm, not urgent by default
- Never pretends to be a contractor or human property manager
- Role is to assist, suggest, draft, and remember
- Knows when to stay quiet

---

## App Structure

The app has three primary tabs, all of which are **house-specific**. Each house has its own chat, contacts, and tasks.

### House Selection

**Top-Level Navigation:**

- House picker/selector at the top of the app (navigation bar or sidebar)
- Users can switch between houses they have access to
- Current house context is maintained across all tabs
- House name/identifier visible in navigation

**UI Considerations:**

- House switcher in navigation bar
- Visual indicator of current house
- Quick access to house settings/profile
- Add new house button (for owners)

### House Management

**Adding a New House:**

1. User taps "Add House" button
2. User goes through onboarding flow for new house
3. House is created with the user as the first owner (via HouseAccess record)
4. After creating house, user can optionally select which existing users should have access
5. User assigns role (owner or member) for each selected user
6. New house appears in house selector

**Empty State:**

- If user has no houses, show empty state with "Add Your First House" prompt
- If user has houses but loses access to all, show appropriate message

**Managing House Access:**

- Access management available from house settings/profile page
- Owners can:
  - View all users with access to this house
  - View pending invitations for this house
  - Add new users (select from existing users or invite by email)
  - Remove users from house
  - Change user roles (owner/member)
  - Cancel pending invitations
- When adding a user to a house:
  - Owner selects user (from existing users) or enters email (creates invitation)
  - Owner selects role for this specific house
  - If existing user: `HouseAccess` created immediately
  - If new user: `Invitation` created, user receives email/in-app notification
  - User gains access to this house only after accepting invitation

**User Management:**

- User management available from app settings (for owners of at least one house)
- Owners can:
  - View all users who have access to at least one of their houses
  - Add new users (invite by email)
  - When adding a user, select which of their house(s) the user should have access to
  - Assign role (owner or member) for each house
  - Remove users from specific houses they own
  - Note: Users cannot be removed from the system entirely if they own houses

### 1. Chat Tab

**Purpose:** Main interface for the product (house-specific)

**Functionality:**

- User asks questions about the current house
- Agent asks questions to learn about the current house
- Agent explains recommendations and reasoning for the current house
- Nudges and notifications are delivered conversationally
- **Each house has its own separate chat history**

**Design Principles:**

- Agent explicitly references what it knows about the house
- Agent is comfortable with partial knowledge and uncertainty
- Messages feel timely and calm, not urgent by default
- Full chat history maintained for context and continuity
- Agent never pretends to be a contractor or human property manager

**UI Considerations:**

- Message bubbles (user vs agent)
- Typing indicators
- Quick action buttons (e.g., "Add to tasks", "Save contact")
- Reference links to house profile, tasks, or contacts
- Timestamp display
- Scroll to bottom on new messages

### 2. Contacts Tab

**Purpose:** House-specific rolodex of vendors and helpers (per house)

**Note:** Each house maintains its own separate contacts list. Contacts are not shared across houses.

**Key Characteristics:**

- Contacts grouped by category based on what the house needs
- Categories exist even if no vendors are saved yet
- Agent suggests vendor categories based on house systems
- Agent can help search for vendors and surface contact information
- Users can favorite vendors they use or add vendors manually
- Contacts are curated, not exhaustive directories

**Contact Data:**

- Name and category
- Contact information (phone, email, address)
- Notes and preferences
- Past work performed
- Favorite status
- Last contacted date

**UI Considerations:**

- Category-based grouping (e.g., "HVAC", "Plumbing", "Landscaping")
- Search functionality
- Add new contact button
- Contact detail view
- Quick actions (call, email, message)
- Work history timeline

### 3. Tasks Tab

**Purpose:** Answers "What does my current house need from me next" (house-specific)

**Note:** Each house has its own task list. Tasks are not shared across houses.

**Key Characteristics:**

- Tasks generated from house profile
- Tasks reflect coordination and decision-making, not just chores
- Tasks grouped by timing and urgency:
  - Now (urgent, needs immediate attention)
  - Soon (this week)
  - This Month
  - Later (future planning)
- Tasks may or may not have fixed dates
- Tasks can be snoozed, deferred, or marked complete
- Tasks can trigger vendor coordination
- Agent can reference tasks in chat and offer to help complete them
- Tasks are a projection of future attention, not a checklist of chores

**Task Data:**

- Title and description
- Category/type
- Priority/urgency
- Due date (optional)
- Status (pending, in progress, completed, snoozed)
- Related systems or house areas
- Related contacts (optional)
- Created date, completed date
- Snooze until date

**UI Considerations:**

- Grouped list by time buckets
- Swipe actions (complete, snooze, delete)
- Task detail view
- Filter by status, category, or system
- Quick add from chat or agent suggestions

---

## Technical Architecture

### Platform

- **Platform:** iOS (native SwiftUI) - iOS only for MVP
- **Minimum iOS Version:** iOS 17.0+
- **Language:** Swift 5.9+
- **Web Companion:** Not included in MVP (iOS-only)

### AI/LLM Integration

- **Provider:** OpenAI API
- **Model:** GPT-4 (or GPT-3.5-turbo for cost optimization)
- **Integration Pattern:**
  - Chat messages sent to OpenAI API with house context
  - System prompt includes house profile, recent history, and agent personality
  - Responses streamed back to UI
  - Conversation history maintained for context

### Data Persistence

- **Primary:** Firebase (Firestore)
  - Real-time sync across devices
  - Offline support
  - User authentication
  - Cloud Functions for server-side logic
- **Local Cache:** SwiftData or Core Data for offline-first experience

### Authentication

- **Method:** Firebase Authentication
  - Email/password
  - Apple Sign In (preferred)
  - Optional: Google Sign In

### Cloud Sync

- **Service:** Firebase Firestore
- **Collections:**
  - Users
  - Houses
  - HouseAccess (user-house relationships with roles - source of truth)
  - Invitations (pending house access invitations)
  - House Profiles (one per house)
  - Tasks (house-specific)
  - Contacts (house-specific)
  - Chat Messages (house-specific)
  - Work History (house-specific)

### Location Services

- **Framework:** Core Location
- **Privacy:** Opt-in only
- **Usage:**
  - Geofencing for arrival/departure detection
  - Location data treated as hint, not source of truth
  - Can be disabled at any time

### Vendor Search Integration

- **API:** Google Places API
- **Endpoints Used:**
  - Text Search: Search by category and location (e.g., "HVAC contractors near [house address]")
  - Nearby Search: Find businesses within radius of house location
  - Place Details: Get full business information (phone, website, hours, reviews)
- **Data Retrieved:**
  - Business name, address, phone number
  - Website URL
  - Ratings and review count
  - Business category/type
- **Privacy:** User's house location used only for search, not stored by Google
- **Cost:** Pay-per-use API (consider caching results)

### Notifications

- **Framework:** UserNotifications
- **Delivery:** Through chat interface (in-app)
- **Push Notifications:** Optional, for critical reminders
- **Principles:**
  - Fewer, better-timed messages
  - Explanations included with nudges
  - Clear opt-out and boundary controls

---

## Data Models

### House Profile

```swift
struct HouseProfile {
    var id: String
    var houseId: String // Reference to House
    var name: String? // Optional friendly name
    var location: Location
    var size: HouseSize?
    var age: Int? // Years since built
    var systems: [HouseSystem]
    var usagePattern: UsagePattern?
    var riskFactors: [RiskFactor]
    var seasonality: Seasonality?
    var createdAt: Date
    var updatedAt: Date
}

struct Location {
    var address: String
    var city: String
    var state: String
    var zipCode: String
    var coordinates: CLLocationCoordinate2D? // Optional
}

struct HouseSize {
    var squareFeet: Int?
    var bedrooms: Int?
    var bathrooms: Int?
    var lotSize: Double? // Acres
}

struct HouseSystem {
    var type: SystemType // heating, water, power, waste, etc.
    var description: String?
    var age: Int? // Years old
    var lastServiced: Date?
    var notes: String?
}

enum SystemType: String, CaseIterable {
    case heating = "Heating"
    case cooling = "Cooling"
    case water = "Water"
    case power = "Power"
    case waste = "Waste"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case roofing = "Roofing"
    case foundation = "Foundation"
    case landscaping = "Landscaping"
    case security = "Security"
    case other = "Other"
}

struct UsagePattern {
    var occupancyFrequency: OccupancyFrequency
    var typicalStayDuration: Int? // Days
    var seasonalUsage: Bool
    var notes: String?
}

enum OccupancyFrequency: String {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case seasonally = "Seasonally"
    case rarely = "Rarely"
}

struct RiskFactor {
    var type: RiskType
    var description: String?
    var severity: RiskSeverity
}

enum RiskType: String {
    case lowOccupancy = "Low Occupancy"
    case winterExposure = "Winter Exposure"
    case remoteLocation = "Remote Location"
    case oldSystems = "Old Systems"
    case other = "Other"
}

enum RiskSeverity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct Seasonality {
    var primarySeason: Season?
    var yearRound: Bool
    var notes: String?
}

enum Season: String {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
}
```

### Task

```swift
struct Task: Identifiable {
    var id: String
    var houseId: String
    var title: String
    var description: String?
    var category: TaskCategory
    var priority: TaskPriority
    var status: TaskStatus
    var dueDate: Date?
    var relatedSystems: [SystemType]
    var relatedContactId: String?
    var createdBy: String // User ID
    var createdAt: Date
    var completedAt: Date?
    var snoozedUntil: Date?
    var notes: String?
}

enum TaskCategory: String {
    case maintenance = "Maintenance"
    case coordination = "Coordination"
    case decision = "Decision"
    case inspection = "Inspection"
    case preparation = "Preparation"
    case other = "Other"
}

enum TaskPriority: String {
    case urgent = "Urgent"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

enum TaskStatus: String {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case snoozed = "Snoozed"
    case cancelled = "Cancelled"
}
```

### Contact

```swift
struct Contact: Identifiable {
    var id: String
    var houseId: String
    var name: String
    var category: ContactCategory
    var phone: String?
    var email: String?
    var address: String?
    var website: String?
    var notes: String?
    var preferences: String? // User preferences for this vendor
    var isFavorite: Bool
    var lastContacted: Date?
    var workHistory: [WorkRecord]
    var createdAt: Date
    var updatedAt: Date
}

enum ContactCategory: String, CaseIterable {
    case hvac = "HVAC"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case landscaping = "Landscaping"
    case roofing = "Roofing"
    case generalContractor = "General Contractor"
    case cleaning = "Cleaning"
    case snowRemoval = "Snow Removal"
    case pestControl = "Pest Control"
    case security = "Security"
    case other = "Other"
}

struct WorkRecord {
    var date: Date
    var description: String
    var cost: Double?
    var outcome: String?
}
```

### Chat Message

```swift
struct ChatMessage: Identifiable {
    var id: String
    var houseId: String // Each house has separate chat history
    var userId: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var relatedTaskId: String? // Task ID (house-specific)
    var relatedContactId: String? // Contact ID (house-specific)
    var quickActions: [QuickAction]? // For agent messages
}

enum MessageRole: String {
    case user = "user"
    case agent = "assistant"
    case system = "system"
}

struct QuickAction {
    var title: String
    var actionType: ActionType
    var payload: [String: Any]?
}

enum ActionType: String {
    case addTask = "add_task"
    case addContact = "add_contact"
    case viewProfile = "view_profile"
    case searchVendor = "search_vendor"
}
```

**Note:** Chat messages are house-specific. Each house maintains its own conversation history with the agent.

### User

```swift
struct User {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date
}
```

### House

```swift
struct House {
    var id: String
    var name: String? // Optional friendly name (e.g., "Lake House", "Cabin")
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String // User ID who created the house (becomes first owner)

    // Denormalized access lists for Firestore security rule performance
    // Synced from HouseAccess collection via Cloud Function
    var ownerIds: [String] // User IDs who own this house
    var memberIds: [String] // User IDs who are members (not owners)

    // Soft delete support
    var isDeleted: Bool // If true, house is archived/deleted
    var deletedAt: Date? // When house was deleted
    var deletedBy: String? // User ID who deleted the house
}
```

**Note:** `ownerIds` and `memberIds` are denormalized from `HouseAccess` for performance. `HouseAccess` remains the source of truth. A Cloud Function syncs changes from `HouseAccess` to these arrays.

### House Access (User-House Relationship)

```swift
struct HouseAccess {
    var id: String
    var userId: String
    var houseId: String
    var role: AccessRole // owner or member
    var grantedBy: String? // User ID who granted access
    var createdAt: Date
}

enum AccessRole: String {
    case owner = "owner"
    case member = "member"
}
```

### Invitation

```swift
struct Invitation: Identifiable {
    var id: String
    var email: String // Email of invitee
    var houseId: String
    var role: AccessRole // Role to be granted
    var invitedBy: String // User ID who sent invitation
    var status: InvitationStatus
    var expiresAt: Date // Invitation expiration (e.g., 7 days)
    var createdAt: Date
    var acceptedAt: Date?
    var acceptedBy: String? // User ID if accepted (may differ from email if user already exists)
}

enum InvitationStatus: String {
    case pending = "pending"
    case accepted = "accepted"
    case expired = "expired"
    case cancelled = "cancelled"
}
```

**Note:**

- Invitations are created when owners invite users to houses
- Invitations expire after a set period (default: 7 days)
- When accepted, a `HouseAccess` record is created and the invitation status is updated
- Invitations can be cancelled by the inviter or expire automatically

- `HouseAccess` is the source of truth for access control. The `House` document contains denormalized `ownerIds`/`memberIds` arrays for Firestore security rule performance.
- A Cloud Function syncs changes from `HouseAccess` to the `House` document's arrays.
- Users can have access to multiple houses. Each house maintains separate chat, contacts, and tasks.
- When a user creates a house, they automatically become an owner (via HouseAccess record).
- Access is managed at the house level - users can have different roles for different houses.

---

## Features

### House Profile Management

**Purpose:** Structured representation of what the agent knows about a specific house

**Note:** Each house has its own separate profile. Profiles are not shared across houses.

**Components:**

- Location
- Size and age
- Core systems (heating, water, power, waste, etc.)
- Usage patterns and seasonality
- Risk factors (low occupancy, winter exposure, etc.)

**Access:**

- Built gradually through conversation (per house)
- Editable through account-style page (house-specific)
- Mirrors what the agent has learned about this specific house
- Can be updated at any time
- Owners can edit, members can view

**UI:**

- Settings/Profile section (house-specific)
- Form-based editing
- Visual representation of completeness
- Agent can reference profile in chat (for current house)

### Onboarding

**Approach:** Conversation-based with the agent

**Initial Questions:**

- Where is the house located?
- How old is the house?
- What are the core systems?
- How often is the house used?

**Principles:**

- Agent asks only questions needed to provide value early
- Additional questions asked opportunistically when they matter
- No long upfront form

**Completion Criteria:**
Onboarding is complete when the agent can:

- Suggest relevant vendor categories
- Generate a useful initial set of tasks

**Flow:**

1. Welcome message from agent
2. Agent asks location
3. Agent asks age
4. Agent asks about systems (guided discovery)
5. Agent asks about usage patterns
6. Agent generates initial tasks and vendor suggestions
7. User can start using the app

### Vendor Discovery

**Capabilities:**

- Agent suggests vendor categories based on house profile
- Agent helps search for local vendors
- Agent surfaces contact information
- Users remain in control of which vendors are saved

**Limitations:**

- Agent never contacts vendors without explicit permission
- No automated booking or scheduling
- Users manually add and manage contacts

**Integration:**

- **Vendor Search API:** Google Places API (Text Search and Nearby Search)
  - Provides business name, address, phone, website, ratings, and reviews
  - Location-based search using house address
  - Category filtering (e.g., "HVAC contractors", "plumbers")
  - Results presented in chat or contacts tab
  - User can save from search results

### Notifications and Nudges

**Delivery Method:** Through chat interface

**Principles:**

- Fewer, better-timed messages
- Explanations included with nudges
- Clear opt-out and boundary controls
- Agent knows when to stay quiet

**Types:**

- Task reminders (gentle, not urgent)
- Seasonal maintenance suggestions
- System service reminders
- Pre-arrival preparation suggestions

**Settings:**

- Notification frequency controls
- Quiet hours
- Notification categories (can disable specific types)

### Location Awareness

**Status:** Optional and opt-in

**Uses:**

- Inferring arrival and departure events
- Timing pre-arrival preparation
- Adding context to task urgency

**Privacy:**

- Location data treated as hint, not source of truth
- Can be disabled at any time
- Clear privacy controls
- No location data shared with third parties

**Implementation:**

- Geofencing around house location
- Significant location changes
- User can manually mark arrival/departure

### History and Memory

**Maintained History:**

- Tasks created and completed
- Vendor work and outcomes
- Recommendations and decisions
- **All chat conversations** (full history maintained for context and continuity)

**Purpose:**

- Support trust and continuity
- Enable long-term value
- Help agent learn house patterns
- Provide audit trail

**Access:**

- Visible in respective tabs
- Referenced by agent in conversations
- Searchable and filterable

### Multi-House Support

**Architecture:**

- Users can have access to multiple houses
- Each house has its own:
  - Chat history (separate conversation per house)
  - Contacts list (house-specific vendors)
  - Tasks list (house-specific tasks)
  - House profile (separate profile per house)
- House selection/switching at the top level of the app
- All tabs are house-specific and show data for the currently selected house

**Use Cases:**

- User owns multiple second homes
- User manages a house and is a member of another house
- Different houses have different systems, vendors, and maintenance needs

### Shared Access (Per House)

**Use Cases:**

- Inviting partner or spouse to share responsibility for a specific house
- Allowing multiple people to ask questions in chat for a house
- Maintaining shared understanding of a specific house

**Principles:**

- All users with access to a house see the same house profile, tasks, contacts, and chat history for that house
- Agent understands shared context across users for the current house
- Actions taken by one user are visible to others for that house
- Designed to reduce coordination overhead
- Access is managed per-house (users can have different access levels to different houses)

**Permissions:**

- **Owners (per house):**
  - Can invite or remove users from this specific house
  - Can edit house profile
  - Can add/remove houses
  - Full access to all features for this house
- **Members (per house):**
  - Can ask agent questions about this house
  - Can view tasks and contacts for this house
  - Can mark tasks complete for this house
  - Cannot edit house profile or manage users
- **Future:** May restrict vendor coordination or settings changes per role

**Access Management:**

**When Adding a User:**

1. Owner selects which house(s) the user should have access to
2. Owner selects role (owner or member) for each house
3. If user exists in system: `HouseAccess` records created immediately
4. If user doesn't exist: `Invitation` records created for each house
5. User receives invitation(s) (email or in-app notification) with list of houses
6. User accepts invitation(s) and gains access to specified houses only
7. Cloud Function syncs access changes to `House` documents

**When Adding a House:**

1. Owner creates new house
2. House is created with `isDeleted: false`
3. `HouseAccess` record created with creator as owner
4. Cloud Function syncs access to `House.ownerIds` array
5. After creating house, user can optionally select which existing users should have access
6. For existing users: `HouseAccess` records created immediately
7. For new users: `Invitation` records created, users receive invitations
8. User assigns role (owner or member) for each selected user
9. New house appears in house selector

**Invitation Flow:**

1. Owner selects house(s) and sends invitation to user (email or in-app)
2. `Invitation` records are created for each house with specified role(s)
3. Invitee receives invitation (email link or in-app notification)
4. Invitee clicks invitation link or accepts in-app
5. If new user: Creates account, then accepts invitation
6. If existing user: Accepts invitation directly
7. `HouseAccess` records are created for specified houses
8. Cloud Function syncs access to `House` document's `ownerIds`/`memberIds` arrays
9. Invitation status updated to "accepted"
10. Invitee gains access to specified houses only
11. All users with access see shared data for each house they can access

**Invitation Management:**

- Invitations expire after 7 days (configurable)
- Owners can cancel pending invitations
- Expired invitations are automatically marked as expired
- Users can see pending invitations sent to their email in-app

**House Deletion (Soft Delete):**

- Only owners can delete houses
- Deletion sets `isDeleted: true`, `deletedAt: now()`, `deletedBy: userId`
- House and all related data remain in database but are hidden from normal queries
- Soft-deleted houses can be restored by owners within retention period (e.g., 30 days)
- After retention period, permanent deletion can be performed via Cloud Function
- Related data (tasks, contacts, messages, profile) remain accessible for audit/recovery

**Edge Cases:**

- If user is removed from a house while viewing it, show access denied message and redirect to house selector
- If user loses access to all houses, show empty state with contact support option
- Last owner cannot remove themselves (must transfer ownership first or delete house)
- If invitation email doesn't match any user, user must create account with that email to accept
- Soft-deleted houses don't appear in house selector or queries (filtered by `isDeleted: false`)
- Users with access to soft-deleted house lose access (house no longer appears in their list)

---

## Onboarding Flow

### Step-by-Step

1. **App Launch**

   - Welcome screen
   - Sign in / Sign up (Firebase Auth)
   - Apple Sign In preferred

2. **First Time User**

   - Agent introduces itself
   - Explains purpose: "I'm here to help you manage your second home..."
   - Asks: "Where is your second home located?" (or "Let's set up your first house")

3. **Location Collection**

   - User provides address
   - Agent confirms and asks: "How old is the house?"

4. **Age Collection**

   - User provides age
   - Agent asks: "What are the main systems in your house?"

5. **System Discovery**

   - Agent presents common systems (heating, water, power, etc.)
   - User selects relevant systems
   - Agent may ask follow-up questions about specific systems

6. **Usage Pattern**

   - Agent asks: "How often do you use the house?"
   - Options: Daily, Weekly, Bi-weekly, Monthly, Seasonally, Rarely
   - Agent may ask about seasonal usage

7. **Initial Setup Complete**

   - Agent generates initial vendor category suggestions
   - Agent creates initial task list based on profile
   - User can start using all tabs

8. **Ongoing Learning**

   - Agent continues to ask questions opportunistically
   - Profile can be edited manually at any time
   - Agent learns from user actions and conversations

9. **Adding Additional Houses**
   - User can add additional houses from house selector
   - Each new house goes through onboarding flow
   - Each house maintains separate profile, chat, contacts, and tasks

---

## Non-Goals

The product explicitly does **not** aim to:

- **Collect payments** - No payment processing or billing
- **Manage rentals** - Not for rental properties or tenant management
- **Control smart home devices** - Not a smart home dashboard or automation platform
- **Replace human judgment** - Agent assists, doesn't replace local expertise
- **Automate vendor communication** - No automated booking, scheduling, or communication
- **Provide real-time monitoring** - Not a security or monitoring system
- **Handle emergencies** - Not a 911 or emergency response system

---

## Success Metrics

### User Experience Metrics

- Users feel "someone understands my house"
- Reduction in forgotten maintenance tasks
- Increased confidence in house management
- Positive sentiment in user feedback

### Engagement Metrics

- Daily/weekly active users
- Chat messages per session
- Tasks created and completed
- Contacts added and used

### Value Metrics

- Time saved on coordination
- Reduction in emergency situations
- Proactive maintenance completion rate
- User retention (especially seasonal users)

---

## Implementation Notes

### MVP Scope (Phase 1)

The MVP focuses on delivering the core value proposition: **an AI agent that understands your house and helps you manage it through conversation.**

**Core Experience:**

1. User signs up and creates their first house
2. Agent asks questions about the house (location, age, systems, usage)
3. User chats with agent about their house
4. Agent provides recommendations and remembers house details
5. User can view and edit house profile

**Why This Phase First:**

- Validates the core value proposition quickly
- Minimal complexity (single house, single user)
- Faster to market
- Allows learning from real usage before adding complexity
- Foundation for all future features

**Simplifications for MVP:**

- Single house per user (no house switching)
- No shared access (single user per house)
- No tasks or contacts tabs (agent can discuss these in chat)
- No invitations system
- Simplified security rules

### Development Phases

**Phase 1 - Core Value (MVP): Chat + House Profile**

**Goal:** Deliver the core value proposition - an AI agent that understands your house and helps you manage it.

**Features:**

- Chat interface with AI agent
- OpenAI API integration (GPT-4 or GPT-3.5-turbo)
- House profile (conversational onboarding)
- Firebase authentication (Apple Sign In, email/password)
- Single house support (simplified - no multi-house yet)
- House profile editing (manual updates)
- Full chat history storage
- Local data persistence (SwiftData for offline support)
- Basic house profile display in settings

**Technical Requirements:**

- Firebase Firestore: `users`, `houses`, `houseProfiles`, `chatMessages` collections
- Firebase Authentication
- OpenAI API integration with streaming
- SwiftData for local caching
- Basic security rules (single user per house for MVP)

**What's NOT included:**

- Multi-house support
- Shared access / invitations
- Tasks tab
- Contacts tab
- Location awareness
- Push notifications
- Vendor search

**Success Criteria:**

- User can chat with agent about their house
- Agent asks questions and learns about the house
- Agent provides relevant recommendations
- House profile is built through conversation
- User can view and edit house profile

---

**Phase 2 - Essential Features: Tasks + Contacts**

**Goal:** Add the coordination and planning surfaces that make the app actionable.

**Features:**

- Tasks tab with grouping (Now, Soon, This Month, Later)
- Task creation, completion, snoozing
- Agent can suggest tasks based on house profile
- Agent can reference tasks in chat
- Contacts tab with categories
- Manual contact entry
- Contact detail view with notes
- Agent can suggest vendor categories
- Enhanced house profile (more complete)

**Technical Requirements:**

- Add `tasks` and `contacts` collections
- Update security rules for new collections
- Task filtering and grouping logic
- Contact categorization

**What's NOT included:**

- Multi-house support
- Shared access
- Vendor search integration
- Work history tracking
- Location awareness

**Success Criteria:**

- User can see and manage tasks for their house
- Agent suggests relevant tasks
- User can maintain vendor contacts
- Agent helps organize contacts by category

---

**Phase 3 - Multi-House & Sharing**

**Goal:** Support multiple houses and enable collaboration.

**Features:**

- Multi-house support
- House selection/switching UI
- House-specific tabs (chat, tasks, contacts per house)
- Shared access (invite users to houses)
- Invitations system
- Access control (owner/member roles)
- House management UI
- User management

**Technical Requirements:**

- Add `houseAccess` and `invitations` collections
- Implement denormalized access arrays in `House` document
- Cloud Functions:
  - Sync HouseAccess to House document
  - Process invitation acceptance
  - Expire old invitations
- Update all queries to filter by house
- Security rules for multi-house access

**What's NOT included:**

- Location awareness
- Push notifications
- Vendor search
- Work history

**Success Criteria:**

- User can manage multiple houses
- Users can share houses with others
- Access control works correctly
- Each house maintains separate data

---

**Phase 4 - Advanced Features**

**Goal:** Add intelligent features that enhance the core experience.

**Features:**

- Google Places API vendor search integration
- Agent can search for vendors and surface results
- Work history tracking for contacts
- Location awareness (opt-in)
- Geofencing for arrival/departure
- Push notifications (optional, for critical reminders)
- Enhanced notifications through chat
- Soft delete for houses
- House restoration

**Technical Requirements:**

- Google Places API integration
- Core Location framework
- UserNotifications framework
- Cloud Function for soft delete processing
- Additional indexes

**Success Criteria:**

- Agent can help find local vendors
- Location features enhance task timing
- Notifications are timely and helpful
- Data recovery is possible

---

**Phase 5 - Polish & Scale (Future)**

**Goal:** Optimize, scale, and add enterprise features.

**Features:**

- Performance optimizations
- Advanced analytics
- Export/backup functionality
- Enhanced agent capabilities
- Custom notification rules
- Advanced task scheduling
- Integration possibilities (smart home, calendars, etc.)

### Technical Decisions

1. **SwiftData vs Core Data:** SwiftData (iOS 17+ native, modern Swift API)
2. **Firebase Structure:** Firestore collections with security rules (see Appendix)
   - **Access Control Denormalization:** `House` document contains `ownerIds`/`memberIds` arrays synced from `HouseAccess` collection via Cloud Function. This enables fast security rule evaluation without multiple `get()` calls.
   - **Source of Truth:** `HouseAccess` collection is the authoritative source. Changes trigger Cloud Function to update `House` document arrays.
   - **Indexes Required:**
     - `houseAccess` collection: Index on `(houseId, userId)` and `(userId, houseId)`
     - `invitations` collection: Index on `(email, status)`, `(houseId, status)`, `(email, houseId)`
     - `tasks` collection: Index on `(houseId, status, dueDate)`
     - `contacts` collection: Index on `(houseId, category)`
     - `chatMessages` collection: Index on `(houseId, timestamp)`
     - `houses` collection: Index on `(isDeleted, createdAt)` for filtering active houses
3. **OpenAI Integration:**
   - Rate limiting and error handling required
   - Cost management: Consider GPT-3.5-turbo for non-critical responses
   - Streaming responses for better UX
   - Context window management: May need to truncate or summarize old messages for very long conversations
4. **Offline Support:** SwiftData for local cache, Firestore for sync
5. **Vendor Search:** Google Places API (Text Search and Nearby Search)
6. **Image Storage:** Not included in MVP (no photos/images for now)
7. **Access Control:**
   - `HouseAccess` collection is the source of truth
   - `House` document contains denormalized `ownerIds`/`memberIds` arrays for security rule performance
   - Cloud Function syncs `HouseAccess` changes to `House` document arrays
8. **Invitations:** Separate `Invitations` collection tracks pending access requests before `HouseAccess` records are created
9. **Soft Delete:** Houses use soft-delete (`isDeleted` flag) instead of hard delete for data recovery and audit trails

### Architecture Decisions

1. **Chat History:** All history stored permanently in Firestore for full context (per house)
2. **Multi-House Support:** Multiple houses per user with house-specific tabs
   - Each house has separate chat, contacts, tasks, and profile
   - House selection at top level of app
   - Access control managed per-house
3. **Platform:** iOS-only for MVP (no web companion)
4. **Vendor Search:** Google Places API for local business search
5. **Agent Memory:** Full conversation history + house profile + recent tasks/contacts for context window (house-specific)
6. **Access Control:** Granular permissions - users can have different access to different houses

---

## Appendix

### Agent System Prompt Template

```
You are Upstate Home Copilot, an AI assistant that helps owners manage their second homes.

Your role:
- Assist, suggest, draft, and remember
- Never pretend to be a contractor or property manager
- Reference what you know about the house explicitly
- Be comfortable with partial knowledge and uncertainty
- Stay calm and timely, not urgent by default
- Know when to stay quiet

House Context (Current House):
[House Profile Data for selected house]

Recent History (Current House):
[Recent tasks, contacts, conversations for this house]

Current Conversation (Current House):
[Chat history for this house]

Guidelines:
- Ask questions to learn about the house when relevant
- Suggest tasks based on house profile and systems
- Recommend vendor categories based on house needs
- Reference specific house details in your responses
- Offer to help complete tasks or coordinate vendors
- Be concise and actionable
```

### Firebase Security Rules (Draft)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Access control uses denormalized arrays in House document for performance
    // HouseAccess collection is source of truth, synced to House via Cloud Function

    // Helper function to check if user has access to a house
    // Uses denormalized ownerIds/memberIds arrays in House document
    function hasHouseAccess(houseId) {
      let house = get(/databases/$(database)/documents/houses/$(houseId));
      return request.auth != null &&
        house != null &&
        !house.data.isDeleted &&
        (house.data.ownerIds.hasAny([request.auth.uid]) ||
         house.data.memberIds.hasAny([request.auth.uid]));
    }

    // Helper function to check if user is owner of a house
    function isHouseOwner(houseId) {
      let house = get(/databases/$(database)/documents/houses/$(houseId));
      return request.auth != null &&
        house != null &&
        !house.data.isDeleted &&
        house.data.ownerIds.hasAny([request.auth.uid]);
    }

    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Houses: users with access can read, owners can write
    match /houses/{houseId} {
      allow read: if hasHouseAccess(houseId);
      allow create: if request.auth != null; // Users can create houses
      allow update: if isHouseOwner(houseId) &&
        (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['isDeleted', 'deletedAt', 'deletedBy']) ||
         request.resource.data.isDeleted == true); // Only allow soft-delete, not hard delete
      // Note: Hard delete not allowed via security rules. Use Cloud Function for permanent deletion if needed.
    }

    // House access: owners can manage, users can read their own
    match /houseAccess/{accessId} {
      allow read: if request.auth != null &&
        (resource.data.userId == request.auth.uid ||
         isHouseOwner(resource.data.houseId));
      allow create: if request.auth != null &&
        (isHouseOwner(request.resource.data.houseId) ||
         request.resource.data.userId == request.auth.uid); // Users can create their own access if invited
      allow update, delete: if request.auth != null &&
        isHouseOwner(resource.data.houseId);
      // Note: Cloud Function should sync changes to House.ownerIds/memberIds arrays
    }

    // Invitations: owners can manage, users can read invitations sent to their email
    match /invitations/{invitationId} {
      allow read: if request.auth != null &&
        (resource.data.email == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.email ||
         isHouseOwner(resource.data.houseId));
      allow create: if request.auth != null &&
        isHouseOwner(request.resource.data.houseId);
      allow update: if request.auth != null &&
        (isHouseOwner(resource.data.houseId) ||
         (resource.data.email == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.email &&
          request.resource.data.status == 'accepted')); // Users can accept invitations sent to their email
      allow delete: if request.auth != null &&
        isHouseOwner(resource.data.houseId);
    }

    // House profiles: users with house access can read, owners can write
    match /houseProfiles/{profileId} {
      allow read: if request.auth != null && hasHouseAccess(resource.data.houseId);
      allow create: if request.auth != null && isHouseOwner(request.resource.data.houseId);
      allow update, delete: if request.auth != null && isHouseOwner(resource.data.houseId);
    }

    // Tasks: users with house access can read/write (only for non-deleted houses)
    match /tasks/{taskId} {
      allow read: if request.auth != null && hasHouseAccess(resource.data.houseId);
      allow create: if request.auth != null && hasHouseAccess(request.resource.data.houseId);
      allow update, delete: if request.auth != null && hasHouseAccess(resource.data.houseId);
    }

    // Contacts: users with house access can read/write (only for non-deleted houses)
    match /contacts/{contactId} {
      allow read: if request.auth != null && hasHouseAccess(resource.data.houseId);
      allow create: if request.auth != null && hasHouseAccess(request.resource.data.houseId);
      allow update, delete: if request.auth != null && hasHouseAccess(resource.data.houseId);
    }

    // Chat messages: users with house access can read/write (only for non-deleted houses)
    match /chatMessages/{messageId} {
      allow read: if request.auth != null && hasHouseAccess(resource.data.houseId);
      allow create: if request.auth != null && hasHouseAccess(request.resource.data.houseId);
      allow update, delete: if request.auth != null && hasHouseAccess(resource.data.houseId);
    }
  }
}
```

### Cloud Functions Required

**1. Sync HouseAccess to House Document**

- Trigger: `houseAccess` collection onCreate, onUpdate, onDelete
- Action: Update `House.ownerIds` and `House.memberIds` arrays based on all `HouseAccess` records for that house
- Ensures denormalized arrays stay in sync with source of truth

**2. Process Invitation Acceptance**

- Trigger: `invitations` collection onUpdate (when status changes to "accepted")
- Action: Create `HouseAccess` record, update invitation status
- Note: The `HouseAccess` creation will trigger the sync function above

**3. Expire Old Invitations**

- Trigger: Scheduled function (runs daily)
- Action: Find invitations where `expiresAt < now()` and `status == 'pending'`, update to `status == 'expired'`

**4. Soft Delete House**

- Trigger: `houses` collection onUpdate (when `isDeleted` changes to true)
- Action: Optionally archive or mark related data (tasks, contacts, messages) as archived
- Note: Hard delete can be implemented separately if needed, with appropriate retention period

---

**Document Status:** This is a living document. Update as decisions are made and features are clarified.
