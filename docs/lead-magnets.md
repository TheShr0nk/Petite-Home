# Petite Home lead-magnet PDFs

Eight downloadable PDFs for the Klaviyo flow. Four are the app's own features
on paper (the ones that convert a download into a subscriber); four come from
research into what moms of young kids actually download and share. They are
built by `lead-magnets/build.py` and committed under `lead-magnets/pdf/`.

## Shared rules

- **Page.** US Letter, 612 × 792 pt, portrait unless noted, 56 pt margins
  (the app's own `PDFExporter` uses the same), content width 500 pt.
- **Fonts.** Fraunces for the wordmark, titles and headings (static instances
  cut from the app's variable TTF), Source Sans Pro for everything else. Both
  are embedded; both are OFL.
- **Colors.** The light values from `PetiteHome/Design/Theme.swift`: cream
  `#FCF8F2` page, creamDeep `#F2E7D8` boxes, powderBlue `#A9CBDD` cover band,
  powderBlueDk `#3F6379` wordmark and the app line, powderBlueMist `#E7EFF4`
  tinted boxes and night hours, sand `#C9B69A` checkbox strokes, sandDeep
  `#6E6259` labels and captions, rule `#E6DBCC` rules, ink `#2B2420` text.
  Danger `#A8584A` is used for one word only, "Never".
- **Type.** Wordmark "PETITE HOME CO." Fraunces 14 pt letter-spaced 0.3 em,
  top-left of every page. Title Fraunces 30 to 40 pt. Section heading Fraunces
  16 to 22 pt with a 1 pt rule under it. Body Source Sans 11 pt. Labels 9 pt
  uppercase letter-spaced 0.16 em.
- **Fill-in rows.** Label left, write-on line right, 20 to 28 pt tall. The
  line starts after the label, however long the label is.
- **Checkboxes.** 12 pt, 1 pt sand stroke, 3 pt radius.
- **Footer.** "Made with Petite Home · petitehome.co" bottom-left, page number
  bottom-right on multi-page files. Every file ends with one italic line in
  powder blue that says what the app does with the same information.
- **Copy rules.** Sentence case, no exclamation points, never "in case of
  death", every empty space says what to do with it.
- **File names.** Lowercase, hyphens, no version numbers: the URL never
  changes once it is in an email.
- **Klaviyo.** One `Downloaded PDF` event per download with a `slug`
  property. The website subscribe endpoint takes a `placement`; use
  `download_<slug>` so attribution matches the app's `ios_app`.

## Suggested sequence

| Day | File | Why then |
|---|---|---|
| 0 | the-family-file | The promise on the sign-up form. |
| 2 | who-to-call-first | One page, the first four onboarding screens. |
| 4 | sitter-cheat-sheet | The first thing a parent needs the week they sign up. |
| 7 | routine-chart | The highest-share item for toddler parents. |
| 10 | baby-sleep-tracker | Highest download for new parents. |
| 14 | milestone-tracker | Pairs with the sleep tracker. |
| 18 | screen-time-agreement | Older kids, keeps the list warm. |
| 21 | if-something-happens | The hardest one, sent once trust exists. Ends with the app link. |

## The files

### the-family-file (cover + 5 pages)
Everything a family needs to know, in one place. Mirrors
`PetiteHome/Services/PDFExporter.swift` and the sections in
`Models/Completeness.swift`: In an emergency, Medical (two child blocks,
health, dental and vision insurance), If something happens to us, Accounts
and money (institution, what it's for, where the login lives), Home and
vehicles (insurance, two vehicles, pets, where things are). Codes are never
on paper: a note says to keep them in the app's vault.

### who-to-call-first (1 page, landscape, folds in half)
The fridge card. Left: if you can't reach us, the kids' doctor, health
insurance, the guardian. Right: three kids with birthdates and allergies, the
address, and "Stick this on the fridge. Put a second copy in the glove box."
Mirrors onboarding screens 1 to 4.

### if-something-happens (3 pages)
The guardian wishes worksheet. Who would step in and a backup, each with
"why them". What we'd want for the kids: where they'd live, school, faith or
traditions, the people we'd want in their lives, what we'd want them to know
about us. Where things are, who we've told, and "Now tell the person. A plan
nobody knows about isn't a plan." Uses the app's line "This isn't legal
paperwork. It's so the people who love you know what you'd want, without
having to guess."

### sitter-cheat-sheet (1 page)
Reworked from the app's `SitterSheet.text` to be the thing you hand over at
the door. Reach us (both parents, a backup, the address). The kids as a table:
name and age, bedtime, allergies, meds and when, what calms them. Tonight's
routine with times. Where things are (snacks, diapers, first-aid kit,
thermometer, flashlight, spare clothes). House rules (screens, treats, doors
and pets). An "If something's wrong" strip with pediatrician, hospital, Poison
Control 1-800-222-1222 and 911. "Never write alarm or gate codes here."

### baby-sleep-tracker (2 pages)
Page 1, landscape: a seven-night log, 24 hour cells per day from 7 pm with the
night hours tinted, shade the hours slept, tick wakes, write the total. Page
2: wake windows by age (typical ranges, labelled as such), a bedtime routine
checklist with times, "Our routine, in order", and the AAP safe-sleep line.

### milestone-tracker (2 pages)
The CDC "Learn the Signs. Act Early." checklists at 2, 4, 6, 9 and 12 months
as tick lists, each with "Photo this month" and "Ask the doctor" lines, then
nine Firsts with date lines (first smile, laugh, rolled over, sat up, tooth,
word, crawled, stood, steps). Caption: if milestones are missed or skills are
lost, talk to the pediatrician; acting early matters.

### routine-chart (3 pages)
Morning (wake up, potty, dressed, breakfast, teeth, shoes and bag, out the
door) and Bedtime (dinner, bath, pajamas, teeth, two books, hugs, lights out)
as seven-row charts. Each row has a box for the child to draw the step and
seven day boxes to tick, with "When a row is full: ____" for the reward. Page
3 is the blank version.

### screen-time-agreement (2 pages)
Page 1, the agreement: when (school days, weekends, where screens are never),
what (apps and shows agreed on), grown-ups too, when it's hard, four signature
lines. Page 2: a week's device log (day, who, what, minutes, felt like),
"Instead, this weekend" with three lines, and five conversation prompts.

## Not built, on purpose

Date night, the expiration tracker, the household cadence, the meal week, the
recipe card, the sealed envelope, the week on one page and the vault checklist
were built first and cut: they duplicated the app rather than earning a
download. The paid planners from the research list (90-day meals, tantrum
toolkit, postpartum, self-care, budget workbooks) are content products that
compete with the subscription; the one paid item that fits is a single bundle
of these eight with the app as the upgrade.
