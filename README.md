# Petite Home — iOS

The household operating system for families with young kids. Three areas plus
Home: **The Family File** (free; the printable export is still titled "The Family
File", as the website promises), the **Planner** (premium: both calendars,
tasks, meals, and family plans with sitters), and the **Vault** (premium).
Names live in `AppCopy` so a rename is one line.

Brand: Petite Home Co. · "Less to question. More to trust."

## Build

The Xcode project is generated from `project.yml`, so the `.xcodeproj` is not
committed.

```
brew install xcodegen
xcodegen generate
open PetiteHome.xcodeproj
```

Then in Xcode:

1. Set your team under Signing & Capabilities (the spec leaves `DEVELOPMENT_TEAM` empty). The App ID needs iCloud (CloudKit) and In-App Purchase; nothing else.
2. Confirm the iCloud container `iCloud.co.petitehome.app` exists in your developer account, or change it in `PersistenceController.cloudContainerID` and the entitlements file.
3. Fill in `RevenueCatAPIKey` and `PostHogAPIKey` in `PetiteHome/Resources/Info.plist`. Both are public SDK keys. Without the RevenueCat key the paywall shows list prices but cannot purchase; without the PostHog key analytics never start.
4. Run. The scheme uses `Products.storekit` so the paywall works in the simulator.

Requirements: Xcode 15.4+, iOS 17.0+, Swift 5.10. Two dependencies via Swift Package Manager: `posthog-ios` and RevenueCat's `purchases-ios`.

## Where things live

```
PetiteHome/
  App/         entry point, AppState (tabs, paywall gate, deep links), RootView, MainTabView
  Design/      Theme.swift (tokens copied from the website), Typography (Fraunces), components
  Models/      SwiftData models, value types, Completeness scoring
  Services/    persistence, CloudKit sharing, keychain, vault crypto, StoreKit, notifications,
               contacts, Vision card scan, PDF export, analytics, Klaviyo, task templates
  Features/    Onboarding, Home, FamilyFile, Children, LifeSync, Tasks, Vault, Picks, Settings,
               Paywall, Export, Sharing
  Resources/   Info.plist, entitlements, StoreKit config, bundled font, asset catalog
PetiteHomeTests/  completeness, age segments, recurrence, crypto, founding codes, card parsing
```

## Design tokens

The site's tokens, confirmed October 2026: cream `#FCF8F2`, creamDeep
`#F4EDE2`, powderBlue `#C9DCE8`, powderBlueDk `#9DBBD0`, sand `#C9B69A`,
sandDeep `#A8927A`, ink `#2F2A26`. Two of them fail WCAG when used as text, so
`Theme.Colors` keeps the exact values for fills and adds a darker cut of the
same hue for text: `accentText` `#4A6A7E` (links, tints, active icons; the
deep blue is 1.9:1 on cream) and `sandDeep` is `#7E6A55` for captions (the
site's brown is 2.8:1), with the site's exact brown available as `sandMid` for
dividers and placeholders. Primary buttons are the deep blue with ink text,
like the icon. Every token is a light/dark pair; see `Theme.swift`.

## Things to know before TestFlight

**Partner sharing on iOS 17.** SwiftData has no CKShare API, so
`CloudSharingService` opens a parallel `NSPersistentCloudKitContainer` over the
same store to create and accept the share. The owner's side is straightforward.
On the partner's device the shared household lands in the `.shared` store,
which SwiftData's `ModelContainer` does not read. This is the single biggest
risk in the ship order and is exactly why the brief gates step 6 on step 5
working across two real devices. If it does not, the fallback is to move the
persistence layer to Core Data + `NSPersistentCloudKitContainer` (the models
are already shaped for it: every attribute has a default, every relationship
is optional). Nothing in the views would change.

**Vault key sharing.** The household's AES key is stored on the Household
record in a field marked `.allowsCloudEncryption`. CloudKit encrypts that
field end to end and hands it to accepted share participants, so a partner on
a different Apple ID opens the vault once the household share works. The
iCloud Keychain keeps a cache for offline use. Gate and alarm codes use a
separate device key that never touches a record.

**Trusted-person links.** These are CloudKit shares with public read-only
permission on a rendered PDF. The recipient needs the app installed to open
the link. The owner's app revokes the share after the expiry date on next
launch.

**Klaviyo.** If the user types an email on the reveal screen, the app posts to the site's existing `/api/subscribe` with
`kind: family-file`, `youngestChildAge`, `placement: app` (the value the site's
`PLACEMENTS` set already accepts; anything else records as `unknown`) and
`source: ios_app` for the profile property.

**Life Sync (premium).** Each phone mirrors its owner's chosen calendars
through EventKit into `CalendarEvent` rows on the household, so the partner
sees them via the household share. Read-only; nothing is written back to the
calendar. Calendar and task choices made during onboarding are held in
`LifeSyncPending` until the trial starts, then applied once. The same step
offers the phone's own Reminders and Calendar apps (`PhoneExportRows`); those
choices ride along in `LifeSyncPending` too. The Tasks tab lives inside Life
Sync as its second segment.

**Onboarding opens on the hook.** There is no intro carousel (the base44 and
HIG guidance both argue against swipe-through intros): the first screen is
"If something happened to you tonight", the first real entry is two taps away,
and there is no sign-up at all. Permissions are asked where they make sense,
each with a one-line reason.

**Swipe to delete.** Tasks, documents, plans, sitters and recipes are cards in
scroll views, so `Design/Components/Swipe.swift` gives them the platform's
swipe-to-delete (reveal on a short swipe, commit on a long one), a long-press
menu with the same action, and a VoiceOver custom action.

**The partner's first open.** A household that arrives through someone else's
share (its `ownerUserID` is not this iCloud user) skips onboarding and gets
`PartnerWelcomeFlow` instead: which adult they are, their own calendars and
phone export, and the notification prompt. Three screens, nothing to re-enter.
The owner is asked about notifications on the "Saved." moment after the
premium step; before that the app never prompts.

**Standing links and paper.** A trusted-person link can be standing: no
expiry, and `StandingLinkRefresher` re-renders and re-uploads the PDF behind
the same link whenever the Family File has changed (on launch, on foreground,
and a minute after an edit). The sharing sheet starts on the guardian and
defaults to standing. The paper sheet offers AirPrint and a printed binder
ordered through the website; see `docs/print-binder.md` for the routes the
site needs and why checkout is on the web (Apple bars in-app purchase for
physical goods). The binder order is behind
`PrintOrderService.isAvailable`, off until the site's print-order routes exist;
while off, the export sheet hides the card and the entry points say paper or PDF.

**Chores: partner notifications, the widget, Reminders.** A chore carries
`createdByAdultID`. When one created on the other adult's phone arrives through
iCloud, `ChoreAnnouncer` posts one local notification ("Casey added a chore")
on this phone, once per chore. It runs on launch, on foreground, and when a
silent CloudKit push wakes the app: `CloudChangeSubscriptions` saves database
subscriptions on the shared and private databases, the app has the
`remote-notification` background mode and the `aps-environment` entitlement,
and the app delegate posts `.cloudChangesArrived` four seconds after a push so
SwiftData has imported the change. The home-screen widget (`PetiteHomeWidget`
target, kind `FamilyChores`, small and medium) reads a JSON snapshot the app
writes to the App Group `group.co.petitehome.app` after every change; ticking
a chore on the widget queues a completion the app applies next time it runs.
Chores already flow to Apple Reminders through `PhoneSyncService`, and that
sync now runs from the same `syncEverything()` on every launch, foreground and
push. Kids are not app users, so "notify the kids" means the printed routine
chart or the Reminders list on a shared iPad for now.

Two capabilities to add on the App ID in the developer portal before this
builds with automatic signing: **App Groups** (`group.co.petitehome.app`, on
both `co.petitehome.app` and `co.petitehome.app.widget`) and **Push
Notifications** (no server is needed; CloudKit sends the pushes).

**Family Sharing.** Premium is per Apple ID. Both products are marked
family-shareable, so the partner is covered only when the buyer has Apple
Family Sharing on; the paywall, Settings and the partner welcome say so. A
partner who still hits the paywall should turn Family Sharing on, then tap
Restore purchases.

**Meals.** The Meals segment of Life Sync holds a recipe box (free) and the
week's plan (premium). Recipes import from any page carrying schema.org
Recipe JSON-LD (`RecipeImporter`, pure and tested), and share out through the
system share sheet as a branded 1080×1350 card plus the recipe text
(`RecipeShare`). Planned meals appear on the Life Sync agenda and as
"Tonight" on Home; the shopping list is computed from the week's recipes.

**Reminders and Calendar on the phone.** `PhoneSyncService` writes tasks into
a "Petite Home" list in the Reminders app (one reminder each, due at the
task's hour, no EventKit recurrence: the app rolls tasks forward and re-points
the reminder) and plans, meals and expirations into a "Petite Home" calendar.
Every item carries an "Added by Petite Home" note. A reminder completed in the
Reminders app completes the task on the next sync. Both channels are per-phone
switches in Settings and run on launch, on return to the foreground, and after
each save. Templates now come in daily ("Plan dinner" at 3 pm), weekly ("Plan
the week together" on Sunday evening, "Grocery run"), monthly and seasonal
cadences.

**Plans.** `FamilyPlan` covers date nights, outings, trips, appointments and
visitors, with who's going and a sitter state (kids come along / need a
sitter / asked / confirmed). `FreeEveningFinder` proposes evenings with
nothing on either synced calendar, weekends first. `SitterSheet` builds the
text sent to a sitter from the Family File: kids' allergies, meds, notes, who to
call, the address. It never includes codes or account details. The sitter
roster is a value list on the household, so both partners share it.

**Unlock without a store (TestFlight).** While `RevenueCatAPIKey` is empty,
the paywall button reads "Unlock while we're testing" and grants premium on
that phone for 30 days, stored in the Keychain, with no purchase. Adding the key switches every trial button to real
RevenueCat purchases; existing local trials run out on their own.

**RevenueCat setup.** Info.plist carries the App Store app's public
`appl_…` key, so debug, TestFlight and release builds all talk to the real
store: the StoreKit configuration file in the simulator when run from Xcode,
Apple's sandbox on a device. A RevenueCat *Test Store* key (`test_…`) can be
swapped in for a quick simulated purchase flow with no App Store Connect
products, but the SDK crashes a Release build that uses one, so
`EntitlementStore.configure()` skips it outside DEBUG, and the Test Store
never returns introductory offers. In the RevenueCat dashboard create the three App Store
products (`co.petitehome.premium.weekly`, `.monthly`, `.annual`) in one
subscription group, all family-shareable. Weekly is $5.99 a week with a
pay-as-you-go intro offer of one period at $0.99 (the first week), monthly is
$14.99 with no intro, annual is $124.99 with no intro. There are no free
trials. The paywall reads each product's intro offer from the store and words
the button and fine print from it (pay-as-you-go and pay-up-front both read
"Start for $0.99"), so the shape can change in App Store Connect without a
code change. The monthly and annual rows show their per-week price and saving
against weekly ("$3.46/wk, save 42%", "$2.40/wk, save 60%"), computed from
store prices. Create an entitlement with the identifier `Premium` (case-sensitive; it matches `ProductID.entitlement`) and a current offering
with `$rc_weekly`, `$rc_monthly` and `$rc_annual` packages. Paste the app's
public API key into Info.plist. `Products.storekit` stays attached to the
scheme so simulator runs from Xcode get the three products, with the weekly
intro offer, without a sandbox account. With a Test Store key instead, the SDK
takes its products from the RevenueCat dashboard's Test Store, so the three
products must be mirrored there (a missing `$rc_weekly` package shows the
weekly row at its list price). The app calls `logIn` with the iCloud user record name so purchases follow
the person across their devices.

**Founding 500 codes.** Format `PH-XXXX-XXXX`; the last group is a checksum of
the first (see `FoundingCode`). Issue codes with `FoundingCode.make(body:)`.

**Verified.** Builds clean on Xcode 26.3 and the 32 unit tests pass from
`xcodebuild test` on a simulator (October 26, 2026). The simulator logs
CloudKit mirroring errors during tests because it has no iCloud account;
that is expected.

## Motion

`Design/Motion.swift` holds the motion vocabulary, ported from Seek Faith:
0.6s crossfades between onboarding screens, staggered fade-ups within a
screen (`.reveal(n)`), the hook's line-by-line reveal, spring selection on
chips and plan rows, a spring pop on task completion, numeric transitions on
the ring, pulsing dots for anything that takes a moment, and one dark "saved"
moment screen after onboarding. Everything honours Reduce Motion.

## Before TestFlight: Apple platform checklist

- App Store Connect: app record, bundle ID `co.petitehome.app` with iCloud
  (CloudKit) and In-App Purchase capabilities (no Sign in with Apple); Paid
  Apps agreement signed; the three subscriptions in one group, weekly at
  $5.99 with a one-period pay-as-you-go intro offer at $0.99, monthly at
  $14.99 and annual at $124.99 with no intro offer, no free trials, all
  family-shareable. The app is subscription-only: after
  onboarding, `RootView` shows the paywall (no close button, with restore and
  the Founding 500 code field) until an entitlement is active.
- CloudKit Dashboard: run the app in Development, then **Deploy Schema
  Changes to Production**. Without that, release builds cannot sync. Both the
  SwiftData store and the parallel Core Data stack in `CloudSharingService`
  write to the same schema.
- `CKSharingSupported` is set in Info.plist; without it iOS never delivers
  share acceptances to the app.
- `PrivacyInfo.xcprivacy` declares email, purchase history and anonymous
  analytics. Update it if a new SDK or data type is added. RevenueCat and
  PostHog ship their own manifests.
- There is no sign-in. Identity is the iCloud user record (`CloudIdentity`),
  so there is no account to delete; Settings offers "Delete this household"
  which removes everything from the phone and iCloud.
- App icon: the wordmark on powder blue, rendered at 1024 from the brand's
  Fraunces by matching the supplied artwork's layout (`docs/app-icon-1024.png`
  is the same file). For iOS 26's layered glass icon, open it in Icon Composer
  on the Mac and export a `.icon` bundle.
- Export compliance: the vault uses CryptoKit AES-GCM, which is standard
  encryption; `ITSAppUsesNonExemptEncryption` is false. Confirm the annual
  self-classification with your counsel if selling outside the US.

## iOS design conventions

Checked against Apple's Human Interface Guidelines and the learnui.design iOS
guide. Body, labels and captions are the system text styles (Body 17, Subhead
15, Footnote 13) and scale with Dynamic Type; the serif headline sizes scale
through `UIFontMetrics`. Every tappable thing is at least 44pt tall: primary
buttons 52, secondary 44, text fields 48, chips and selectable rows 44, icon
buttons 44x44 with accessibility labels. Screen gutter is 20pt (the site's
grid; Apple's default is 16). Navigation, tab bar, sheets, lists and alerts
are the system components, so they pick up iOS 26's Liquid Glass on their own.
Chips and selectable rows give selection haptics.

**Dark mode.** Every token in `Theme.Colors` is a light/dark pair
(`Color(light:dark:)`), so no view branches on the scheme. The dark side is the
same warm family: near-black cream, lighter sand for secondary text, a deeper
powder blue that white text still reads on. The dark "moment" screens and the
paywall's ink card use `Theme.Colors.Fixed` so they look the same in both.
Settings has an Appearance picker (match the phone, light, dark). All text
pairs meet WCAG AA in both modes; the one near-miss is powder blue used as
accent text in the dark (4.1:1 at label sizes).

**Liquid Glass (iOS 26).** `Design/Glass.swift` wraps the iOS 26 APIs behind
availability checks, so the iOS 17 build keeps the flat look: primary buttons
are tinted interactive glass, outline and secondary buttons clear glass, chips
glass capsules, the onboarding action bar floats over the scrolling content in
a `GlassEffectContainer`, scroll edges fade under the bars, and the tab bar
minimises on scroll. Cards, lists and text stay on the cream ground, as Apple
asks. Still to do on the Mac: a layered app icon from Icon Composer, which the
placeholder icon cannot be.

## Copy rules

Sentence case. No exclamation points. Never "in case of death". Empty states
say what to do. Every premium lock says "Premium keeps this for you".
