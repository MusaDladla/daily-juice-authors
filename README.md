# Daily Juice Authors

An Android and iOS app for authors of *The Daily Juice* devotional, a Discipleship
tool of Youth For Christ reaching about 3.6 million souls a month. The author writes;
the app formats the content into the official Daily Juice template and exports
the finished page as a high-quality image.

**Author writes → content is fitted into the exact template → preview → export.**

## Workflow

1. **Create profile** (once): name, surname, profile photo, and optionally the
   Youth For Christ branch. The photo is framed automatically. Drag it, use the
   arrows to move it up, down, left and right, or zoom. It is never distorted,
   and a live preview shows the header exactly as it will print.
2. **Create Daily Juice**: title, date, Theme Scripture + reference, main
   message, Further Study references.
3. **Live preview**: the real template, updating as you type (pinch to zoom).
4. **Generate Daily Juice**: final validation, then a 2480 × 3508 px PNG.
5. **Save / Share**: save to the gallery ("The Daily Juice" album) or share
   straight to WhatsApp, Facebook, Instagram, etc.

## Dashboard

Kept minimal: the ministry header, a welcome line, **Create Daily Juice**, and
**My Daily Juices**: one list holding every Daily Juice exactly once.

- Drafts are marked DRAFT with when they were last edited; tap one to continue
  writing. Drafts save as you type and the moment the app is left.
- Search by title or date ("october", "8 October 2026", "08/10/2026",
  "Thursday"), a calendar that offers only days that have a Daily Juice, and
  All / Drafts / Generated filters. Results are grouped by month.
- Footer: "Created by Youth For Christ".

## Writing aids

- **Live strip while typing**: with the keyboard open, a strip of the real
  page follows the part being edited (header, scripture, the latest lines of
  the message, or the footer). Tap it for the full page; it can be hidden.
- **Smart paste**: pasting text that is over a limit opens a "Shorten" sheet
  with the full pasted text and a live counter. It is only inserted once it
  fits, and nothing is cut automatically.
- **Progress**: each section shows ✓ when complete; the bottom bar shows
  "3 of 5 sections complete" or "Ready to generate".
- Drafts save automatically. A note appears if another Daily Juice already
  uses the chosen date. Enter on the last reference starts the next one.
- Each Daily Juice in the list shows a live thumbnail. Generated images are
  reused instead of re-rendered.

## Grammar check (Main Message)

**CHECK GRAMMAR** under the Main Message asks LanguageTool (free, no account)
for spelling and grammar suggestions in South African English. Each suggestion
shows the mistake in context. The author picks a correction or **Keep as is**
(the default), or uses **Accept all**. Nothing changes unless chosen, and the
result must still fit the word and page limits. The Title and Theme Scripture
are never checked. It needs an internet connection, and the text is sent to
languagetool.org.

## Content limits (enforced while typing)

| Field | Limit | Message |
|---|---|---|
| Title | 7 words; a title longer than about 19 letters ("THE LORD OUR MAKER" + 1) moves to two balanced lines at full size, 126 px apart as in the official artwork (max 60 chars) | "Title cannot exceed 7 words." |
| Theme Scripture | 38 words (reference not counted) | "Theme Scripture cannot exceed 38 words." |
| Main Message | 171 words, or more while the page has free space at standard spacing (e.g. after a short verse) | "Your message cannot exceed 171 words because the page has no free space left." |
| Further Study | 1–3 Bible references | "You can only add a maximum of 3 Further Study references." |

An edit that would break a limit (typing *or* pasting) is refused. The
existing text is left untouched and the reason is shown. Content is never
rewritten, shortened, summarised or padded. The only presentation applied
is what the template itself shows: uppercase title/author/date/references,
and parentheses around the Scripture reference.

Words are whitespace-separated tokens that contain a letter or digit, so
punctuation never counts ("God is good." = 3 words).

## The template

`lib/template/template_spec.dart` holds every coordinate of the official
artwork, measured at its native 2480 × 3508 px (A4 @ 300 dpi). The fonts
are bundled so every phone renders identically:

- **Barlow Condensed** (Bold / SemiBold / Light): title, author, date,
  Theme Scripture, reference, Further Study.
- **Arimo** (metrically identical to Arial): message, drop cap,
  "FURTHER STUDY", "next page".

The reference Daily Juice ("Baal Perazim") is reproduced line for line by the
engine, and every element sits within a few pixels of the original
(`test/template_reference_test.dart`).

### How the page always fits

- Fonts never shrink. The template is fixed.
- A long 4-word title may use two lines at full size inside the title box.
- The Theme Scripture area takes exactly the space the verse needs: 4 lines
  sit as in the artwork, a shorter verse closes up (the message moves up, so no
  empty space is left), and a longer one moves the message down.
- Paragraphs are separated by one blank line, as in the original. If and only
  if the content would otherwise not fit, that gap tightens uniformly, never
  below half a line.
- If content still would not fit, the edit is refused at input time
  ("There is no more space on the Daily Juice page…"). The page-space meter
  under the message shows how full the page is.

## Project layout

```
lib/
  core/       limits & messages, word count, dates, Bible-reference check,
              input limit formatter, final validation
  template/   template spec, layout engine, painter (preview + export)
  models/     Profile, DailyJuice (versioned JSON)
  data/       on-device storage (app documents folder)
  ui/         profile, home, editor, result screens
assets/fonts/ bundled template fonts (SIL Open Font License)
test/         rules, fit/integrity, and reference-reproduction tests
tool/         launcher icon generator
```

## Develop

```sh
flutter test                         # 96 tests
flutter run                          # debug on a connected phone
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
```

Render the reference page to a PNG for visual comparison:

```sh
DJ_RENDER_OUT=out.png flutter test test/template_reference_test.dart
```

The release build is currently signed with the debug key, which is fine for
installing on your own phones. Create an upload key before publishing to the
Play Store.

### iOS

The same code runs on iPhone and iPad (iOS 13+, bundle ID
`com.thedailyjuice.dailyJuice`). iOS apps can only be compiled on macOS:

- **On a Mac** with Xcode: `flutter run` on a connected iPhone, or
  `flutter build ipa` for a signed App Store / TestFlight build (needs an
  Apple Developer account; set the team in Xcode under Runner → Signing).
- **Without a Mac**: push to GitHub and run the **iOS build** workflow
  (`.github/workflows/ios.yml`). It tests the app, builds it on a GitHub Mac,
  and attaches an unsigned `DailyJuiceAuthors.ipa` to the run. Install it
  with Sideloadly or AltStore, which sign it with your Apple ID (with a free
  Apple ID the app must be re-installed every 7 days).

iPhones cannot install an app from a file sent on WhatsApp: iPhone authors
use TestFlight / the App Store (Apple Developer account) or the web version.

### Web version (iPhone authors without the App Store)

The same app runs in Safari. The **Web version** workflow
(`.github/workflows/web.yml`) tests it, builds it and publishes it on GitHub
Pages on every push to `main`. Authors open the link, then tap
Share → **Add to Home Screen** so it opens full screen like an app.

Differences from the phone apps:

- Drafts, the profile and generated images are kept in the browser's site
  storage (IndexedDB) on that phone. Opening the Home Screen icon keeps them;
  clearing Safari's website data removes them.
- **Save** opens the iPhone share sheet: "Save Image" puts the page in
  Photos. On a computer it downloads the PNG.

```sh
flutter build web --release --base-href /<repository>/   # build/web
```

`flutter test tool/generate_launcher_icons.dart` writes the iOS and web icons
and launch logos as well as the Android ones.
