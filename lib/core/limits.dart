/// Fixed content limits of the Daily Juice template.
///
/// These are part of the core publication rules: the template never changes
/// to accommodate content — the author's content must fit these limits.
class Limits {
  Limits._();

  /// A long title uses a second line (same size) in the title box.
  static const int titleWords = 7;

  /// Safeguard so an extremely long title cannot overflow the title box.
  /// The real guard is the measured two-line fit check in the layout engine.
  static const int titleChars = 60;

  static const int scriptureWords = 38;
  static const int scriptureReferenceChars = 40;

  /// The standard Main Message limit. Beyond it, words are allowed only
  /// while they fill genuinely free page space (e.g. left by a short Theme
  /// Scripture) at standard paragraph spacing.
  static const int messageWords = 171;

  static const int furtherStudyRefs = 3;
  static const int furtherStudyRefChars = 40;

  /// A Bible reference never needs more words than this
  /// ("1 Song of Solomon 2:4-7 NKJV" is 6). Anything longer is verse text.
  static const int furtherStudyRefWords = 7;

  static const int nameChars = 40;
  static const int branchChars = 60;
}

/// User-facing validation messages.
class Msg {
  Msg._();

  static const titleWords = 'Title cannot exceed 7 words.';
  static const titleChars =
      'Title cannot exceed ${Limits.titleChars} characters.';
  static const titleWidth =
      'This title is too long to fit the title area. Please use shorter words.';
  static const titleRequired = 'Title is required.';

  static const dateRequired = 'Date is required.';

  static const scriptureWords = 'Theme Scripture cannot exceed 38 words.';
  static const scriptureRequired = 'Theme Scripture is required.';
  static const scriptureReferenceRequired =
      'Scripture reference is required (e.g. 2 Samuel 5:20).';
  static const scriptureReferenceInvalid =
      'The Scripture reference should look like a Bible reference '
      '(e.g. 2 Samuel 5:20).';
  static const scriptureReferenceChars =
      'Scripture reference cannot exceed ${Limits.scriptureReferenceChars} characters.';

  static const messageRequired = 'Main Message is required.';

  static const messageNoFreeSpace =
      'Your message cannot exceed 171 words because the page has no free '
      'space left.';
  static const pageFull =
      'There is no more space on the Daily Juice page. Shorten the message '
      'or use fewer paragraph breaks.';
  static const pageFullScripture =
      'There is no more space on the Daily Juice page for a longer Theme '
      'Scripture. Shorten the Main Message first.';

  static const furtherStudyMax =
      'You can only add a maximum of 3 Further Study references.';
  static const furtherStudyRequired =
      'Add at least one Further Study Bible reference.';
  static const furtherStudyRefOnly =
      'Further Study is for Bible references only (e.g. ISAIAH 28:21), '
      'not verse text.';
  static const furtherStudyInvalid =
      'This does not look like a Bible reference (e.g. ISAIAH 28:21).';
  static const furtherStudyChars =
      'A reference cannot exceed ${Limits.furtherStudyRefChars} characters.';
  static const furtherStudyWidth =
      'These references are too long to fit the Further Study line.';

  static const profileImageRequired = 'Profile image is required.';
  static const nameRequired = 'Name is required.';
  static const surnameRequired = 'Surname is required.';
  static const authorTooLong =
      'Your name and surname are too long to fit the author line of the '
      'Daily Juice.';
}
