# Petite Home lead-magnet PDFs

Twelve downloadable PDFs for the Klaviyo flow, each one a paper version of a
feature in the iOS app. Build them in the website repo (`petite-powder`) so
they are hosted on petitehome.co and linked from Klaviyo emails. This file is
the spec: shared brand rules first, then one entry per PDF.

Fill-in versions are the default: every PDF is designed to be printed and
written on. Where the app already renders a file from real data (1, 2, 3), the
blank PDF uses the same layout as the app's export so the two match.

## Build notes for Claude Code

- **Where.** `02-web/public/downloads/<slug>.pdf`, generated from
  `02-web/scripts/pdfs/<slug>.tsx` (or `.ts`) with `@react-pdf/renderer`, run
  by `npm run pdfs`. Commit the generated PDFs so Klaviyo links are stable.
- **Fonts.** Fraunces (variable TTF, already in `00-brand`) for headings and
  the wordmark, Inter or system sans for body. Embed both; never rely on
  system fonts in a PDF.
- **Page.** US Letter, 612 × 792 pt, portrait unless the entry says
  otherwise. 56 pt margins on all sides (the app's `PDFExporter` uses the
  same). Content width 500 pt.
- **Colors.** From `00-brand/color/tokens.css` and
  `PetiteHome/Design/Theme.swift` (light values only, PDFs are always light):
  cream `#FCF8F2` page, creamDeep `#F2E7D8` boxes, powderBlue `#A9CBDD`
  bands and selected marks, powderBlueDk `#3F6379` accent text and the
  wordmark, powderBlueMist `#E7EFF4` section grounds, sand `#C9B69A` icons
  and checkbox strokes, sandDeep `#6E6259` secondary text, rule `#E6DBCC`
  1 pt rules, ink `#2B2420` body text. Danger `#A8584A` only for the word
  "Never" in the vault and sitter sheets.
- **Type scale.** Wordmark "PETITE HOME CO." Fraunces 14 pt, letter-spaced
  0.3 em, powderBlueDk, top-left of every page. Title Fraunces 40 pt ink.
  Section heading Fraunces 22 pt ink, 24 pt above, 12 pt below, a 1 pt rule
  in `rule` under it. Body sans 11 pt ink, 1.45 line height. Labels sans
  9 pt sandDeep, uppercase, letter-spaced 0.16 em. Captions sans 9 pt
  sandDeep.
- **Fill-in rows.** Label on the left in the label style, a 1 pt sandDeep
  write-on line to the right, 28 pt row height so handwriting fits. Boxes:
  creamDeep fill, 10 pt corner radius, 14 pt padding.
- **Checkboxes.** 12 pt squares, 1 pt sand stroke, 3 pt radius, 8 pt gap to
  the label.
- **Footer on every page.** Sans 9 pt sandDeep, bottom-left: "Made with
  Petite Home · petitehome.co". Bottom-right: page number when there is more
  than one page.
- **Cover rule.** Only PDFs 1 and 2 get a cover page (the app's cover: a
  powder blue band across the bottom third, title at y 260, subtitle under
  it, date). All others start on the content immediately with the wordmark
  and title at the top.
- **Copy rules** (from the brand): sentence case everywhere, no exclamation
  points, never the phrase "in case of death", say what to do in every empty
  space, never "in case of emergency" as a heading (the app says "In an
  emergency").
- **Metadata.** PDF title = the document title below, author "Petite Home
  Co.", subject = the one-line purpose. Tag the PDFs for accessibility if the
  renderer supports it; at minimum the reading order must follow the layout.
- **File naming.** Lowercase, hyphens, no version numbers in the public
  name: the URL never changes once it is in a Klaviyo email.
- **Klaviyo.** One Klaviyo event per download, `Downloaded PDF` with
  property `slug`. Suggested sequence: day 0 PDF 1, day 2 PDF 5, day 4 PDF
  6, day 7 PDF 7, then one a week from the rest, ending with the app link.
  The website's subscribe endpoint already takes a `placement`; add
  `download_<slug>` placements so attribution matches the app's `ios_app`.

## The PDFs

### 1. The Family File

- **Slug.** `the-family-file`
- **Purpose.** The flagship. Everything a family needs to know, in one
  printable place. This is what the email capture already promises.
- **Pages.** Cover + 5 content pages, one per section.
- **App source.** `PetiteHome/Services/PDFExporter.swift` renders the filled
  version; `PetiteHome/Models/Completeness.swift` lists the sections and
  fields. Mirror its section order and labels exactly.
- **Cover.** Wordmark. Title "The Family File". Subtitle "Everything a
  family needs to know, in one place." Line: "Filled in on ______". Powder
  blue band bottom third with, in cream, "Keep one copy at home and one with
  the person you'd call first."
- **Sections and fill-in rows.**
  1. *In an emergency.* Who to call first (name, relationship, phone).
     Second contact (same). Home address. Preferred hospital (name, phone).
     Gate or alarm code: a note, not a line: "Keep codes in the app's vault,
     not on paper."
  2. *Medical.* Per child, two blocks on the page: name, birthdate,
     pediatrician (name, phone), allergies, medications (name, dose, when),
     blood type, notes. Health insurance: carrier, member ID, group number,
     phone on the card. Dental and vision: carrier, member ID.
  3. *If something happens to us.* Guardian (name, relationship, phone).
     Backup guardian. "What we'd want for the kids" as a 6-line free box.
     Where the will is. Lawyer (name, phone). The app's line as a caption:
     "This isn't legal paperwork. It's so the people who love you know what
     you'd want, without having to guess."
  4. *Accounts and money.* Rows for: bank, mortgage or rent, utilities (4
     rows), phone plan, subscriptions (3 rows), life insurance (carrier,
     policy number, agent phone). Each row: institution, what it's for,
     where the login lives. Caption: "Write where the password is kept,
     never the password."
  5. *Home and vehicles.* Home insurance (carrier, policy, phone). Each
     vehicle (2 blocks): make and model, plate, registration renews on,
     insurance policy. Pets (2 rows): name, vet, phone. Where things are:
     water shutoff, breaker panel, spare key, important papers.
- **Last page footer line.** "Done on paper? The app keeps it current, syncs
  it with your partner and reminds you when things expire. petitehome.co"

### 2. The sealed envelope

- **Slug.** `sealed-envelope`
- **Purpose.** The version you hand to grandparents or the guardian. Same
  sections as 1 without numbers that shouldn't travel. Follow-up email.
- **Pages.** Cover + 3.
- **App source.** `PDFExporter` with `tier: .clean`.
- **Differences from 1.** Cover title "Sealed envelope", subtitle "For the
  person who'd step in. Open when you need to." Omit: insurance member and
  group numbers, account rows, vehicle plates and policies, codes. Keep: who
  to call, address, hospital, each child's medical block, guardian block,
  where the will is, where things are in the house. Add a front line:
  "Prepared by ______ on ______."

### 3. The sitter sheet

- **Slug.** `sitter-sheet`
- **Purpose.** One page to leave on the counter for a sitter. The app sends
  this as a text; the PDF is the fill-in version.
- **Pages.** 1.
- **App source.** `SitterSheet.text(plan:household:sitterName:)` in
  `PetiteHome/Models/FamilyPlan.swift`. Same order of information.
- **Layout.** Title "Tonight". Top line: "We'll be out from ____ to ____, at
  ____." Then a box per child (3 boxes): name and age, bedtime, allergies,
  meds and when, "what works" (one line). A free box "House notes" (where
  snacks are, screen rules, the dog). "If you can't reach us" block: our
  phones (2), a neighbor or relative (name, phone), pediatrician (name,
  phone), hospital, our address. Bottom caption in danger color on the word
  only: "**Never** put alarm or gate codes on this sheet. Tell the sitter
  in person."
- **Footer line.** "The app fills this in from your Family Vault and texts
  it to the sitter. petitehome.co"

### 4. The recipe card

- **Slug.** `recipe-card`
- **Purpose.** A blank card to write a family recipe on, matching the app's
  shareable card. Social asset more than email; include it in the Meals
  email as a bonus.
- **Pages.** 1, portrait, two cards per page with a dotted cut line.
- **App source.** `PetiteHome/Services/RecipeShare.swift` (1080 × 1350 card:
  wordmark, serif title, summary, sand rule). Keep its proportions at
  4 × 5 in.
- **Layout per card.** Wordmark small. "Recipe" label. Title line (Fraunces
  write-on line). "Serves ____ · ____ minutes". Ingredients: 10 short lines
  in a left column. Steps: 6 numbered lines on the right. Bottom: "From the
  kitchen of ______".

### 5. Who to call first

- **Slug.** `who-to-call-first`
- **Purpose.** The fridge card. The first four onboarding screens on one
  page. Day-2 email.
- **Pages.** 1, landscape (792 × 612), designed to fold in half to 5.5 × 8.5.
- **App source.** Onboarding screens 1 to 4 in
  `PetiteHome/Features/Onboarding/OnboardingScreens.swift`: first contact,
  pediatrician, insurance, guardian.
- **Layout.** Left half, large: title "Who to call first". Four rows with
  big write-on lines: "If you can't reach us" (name, phone), "The kids'
  doctor" (name, phone), "Health insurance" (carrier, member ID, phone on
  the card), "If something happens to us" (guardian name, phone). Right
  half: "The kids" with three rows (name, birthdate, allergies), our address,
  and a powderBlueMist box: "Stick this on the fridge. Put a second copy in
  the glove box."
- **Hook line** at the top in sandDeep: "If something happened to you
  tonight, would anyone know where to find this?"

### 6. The expiration tracker

- **Slug.** `expiration-tracker`
- **Purpose.** Everything that quietly expires, with the app's reminder rule.
  Day-4 email, maps to premium reminders.
- **Pages.** 1.
- **App source.** `PetiteHome/Services/ExpirationScheduler.swift` (what
  counts as an expiration) and the 60 / 30 / 7 day reminders in
  `NotificationService`.
- **Layout.** Title "What expires". Intro: "Three reminders is the rule: 60
  days out, 30, then 7. Write the dates, then set the reminders, or let the
  app do it." Table, 14 rows, columns: Item · Expires on · Remind 60 days ·
  Remind 30 · Remind 7 (the last three as checkboxes). Pre-printed items in
  sandDeep: each passport (3 rows), car seat (expiry is stamped on the seat),
  car registration (2), driver's licenses (2), health insurance renewal,
  home or renter's insurance, life insurance premium, EpiPen or inhaler,
  smoke detector batteries, then 2 blank rows.
- **Caption.** "Car seats expire. The date is on a sticker on the seat,
  usually 6 to 10 years from manufacture."

### 7. The household cadence

- **Slug.** `household-cadence`
- **Purpose.** The app's task pack on paper: the things a house needs, by
  rhythm. Day-7 email, maps to the Planner's tasks.
- **Pages.** 2.
- **App source.** `TaskTemplate.pack` in
  `PetiteHome/Services/TaskTemplates.swift` (titles, cadence, notes, the
  default hour and weekday). Use the same titles.
- **Layout.** Page 1, title "The house, on a rhythm". Five groups with
  checkboxes and the app's note under each item: *Every day* (Plan dinner,
  Ten-minute tidy), *Every week* (Plan the week together · Sunday evening,
  Grocery run · Saturday), *Every month* (Look at what's coming due, Check
  car seat straps and fit), *A few times a year* (Change the furnace filter ·
  every 3 months, Replace smoke detector batteries · every 6 months, Flush
  the water heater · every 6 months), *Every year* (Renew car registration,
  Review insurance coverage, each child's well-child visit around the
  birthday). Three blank lines per group for the family's own. Page 2: a
  month grid, 5 rows × 7 columns, with "Who" and "Done" tick columns for
  the weekly items, meant to be printed each month.
- **Caption.** "Pick the ones that fit. Either of you can check one off."

### 8. If something happens to us

- **Slug.** `if-something-happens`
- **Purpose.** The guardian wishes worksheet. The hardest page and the one
  most families never write. Week-2 email.
- **Pages.** 2.
- **App source.** Onboarding guardian screen and the
  `ifSomethingHappens` section in `Completeness.swift`; the app's subline
  "This isn't legal paperwork. It's so the people who love you know what
  you'd want, without having to guess."
- **Layout.** Page 1, title "If something happens to us". The subline above
  as the intro. Blocks: "Who would step in" (name, relationship, phone, why
  them, in two lines). "A backup, in case" (same). "What we'd want for the
  kids": prompts with lines under each: where they'd live, school, faith or
  traditions, the people we'd want in their lives, what we'd want them to
  know about us. Page 2: "Where things are": the will, life insurance,
  accounts, the Family File. "Who we've told": three rows (name, date).
  Closing box in powderBlueMist: "Now tell the person. A plan nobody knows
  about isn't a plan."
- **Never** use the phrase "in case of death" anywhere on this page.

### 9. The week on one page

- **Slug.** `week-on-one-page`
- **Purpose.** The Planner's week view as a paper planner for two adults.
  Week-3 email.
- **Pages.** 1, landscape.
- **App source.** `LifeSyncAgenda` in `PetiteHome/Models/CalendarEvent.swift`
  (event, task, meal, plan rows per day) and the week view in
  `PetiteHome/Features/LifeSync/LifeSyncView.swift`.
- **Layout.** Title "This week", "Week of ______". Seven columns Monday to
  Sunday. Each column, top to bottom: two thin bands labelled with each
  adult's name (write-on at the top of the page: "____ and ____"), a
  "Kids" band, a "Dinner" row, a "Who's on bedtime" row, a "Sitter?" tick.
  A right-hand strip, 90 pt wide: "This week's three" (three checkboxes),
  "Date night" (one line), "Next week, already" (two lines).

### 10. The meal week and shopping list

- **Slug.** `meal-week`
- **Purpose.** Decide dinner once. Seven slots and a grouped list. Week-4
  email, maps to Meals.
- **Pages.** 1.
- **App source.** `PlannedMeal`, `MealSlot` and `ShoppingList` in
  `PetiteHome/Models/Meals.swift`; the app groups the list by aisle.
- **Layout.** Left 55 percent: title "Dinner this week", seven rows Monday
  to Sunday with "What" and "Who cooks" columns and a "Leftovers" tick.
  Right 45 percent: "The list", grouped the way the app does: Produce,
  Meat and fish, Dairy and eggs, Pantry, Frozen, Household; six lines per
  group with checkboxes. Bottom caption: "Three dinners you always come back
  to:" with three lines.

### 11. What to keep in the vault

- **Slug.** `what-to-keep-in-the-vault`
- **Purpose.** A checklist of the documents worth photographing and where
  the originals live. Maps to the Vault. Week-5 email.
- **Pages.** 1.
- **App source.** `VaultCategory` in `PetiteHome/Models/ValueTypes.swift`
  and the Vault's empty state copy ("A photo of a birth certificate is a good
  start.").
- **Layout.** Title "What to keep". Intro: "A photo of a birth certificate is
  a good start. Here's the rest." Three columns of checkboxes with a "Where
  the original is" line under each: *Identity* (birth certificates, Social
  Security cards, passports, marriage certificate), *Medical* (insurance
  cards front and back, vaccination records, prescriptions), *Home and money*
  (deed or lease, vehicle titles, insurance policies, the will, tax returns,
  warranties). Bottom box with the word in danger color: "**Never** keep
  these as plain photos in your camera roll. The app encrypts them on your
  phone and in your iCloud, and only you can open them."

### 12. Date night, found

- **Slug.** `date-night-found`
- **Purpose.** The free-evening finder as a worksheet: two weeks of evenings,
  cross out what's taken, circle two. Week-6 email, the lightest of the set.
- **Pages.** 1.
- **App source.** `FreeEveningFinder` in `PetiteHome/Models/FamilyPlan.swift`
  (weekends first) and `SitterStatus`.
- **Layout.** Title "Find the evening". Fourteen large boxes in two rows,
  Monday to Sunday twice, weekends tinted powderBlueMist. Each box: the day
  name, a "Taken by" line, a circle to mark it. Under the grid: "Two we
  circled: ______ and ______". "Sitter" block: three rows (name, phone, asked
  on, confirmed tick). "The ask, ready to text" in a box, from the app's
  `SitterSheet.askText`: "Hi ____, are you free on ____ from ____ to ____? The
  kids would love to see you."
