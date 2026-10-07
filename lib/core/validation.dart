import '../models/daily_juice.dart';
import '../template/template_layout.dart';
import 'bible_reference.dart';
import 'limits.dart';
import 'word_count.dart';

enum JuiceField {
  profileImage,
  name,
  surname,
  branch,
  title,
  date,
  scripture,
  scriptureReference,
  message,
  furtherStudy,
}

class Issue {
  const Issue(this.field, this.message);

  final JuiceField field;
  final String message;

  @override
  String toString() => '${field.name}: $message';
}

class Validation {
  Validation._();

  /// The parts of a Daily Juice the author fills in, for progress display.
  static const List<List<JuiceField>> sections = [
    [JuiceField.title],
    [JuiceField.date],
    [JuiceField.scripture, JuiceField.scriptureReference],
    [JuiceField.message],
    [JuiceField.furtherStudy],
  ];

  static int sectionsComplete(List<Issue> issues) => sections
      .where((fields) => !issues.any((i) => fields.contains(i.field)))
      .length;

  /// Profile rules. The Youth For Christ branch is optional.
  static List<Issue> profile({
    required String name,
    required String surname,
    required bool hasPhoto,
  }) {
    final issues = <Issue>[];
    if (!hasPhoto) {
      issues.add(
        const Issue(JuiceField.profileImage, Msg.profileImageRequired),
      );
    }
    if (name.trim().isEmpty) {
      issues.add(const Issue(JuiceField.name, Msg.nameRequired));
    }
    if (surname.trim().isEmpty) {
      issues.add(const Issue(JuiceField.surname, Msg.surnameRequired));
    }
    if (name.trim().isNotEmpty &&
        surname.trim().isNotEmpty &&
        !TemplateLayoutEngine.authorFits('${name.trim()} ${surname.trim()}')) {
      issues.add(const Issue(JuiceField.surname, Msg.authorTooLong));
    }
    return issues;
  }

  /// Whether a Main Message of [words] words fits the page in [layout].
  ///
  /// Up to 171 words it only has to fit (paragraph spacing may tighten
  /// slightly if needed). Beyond 171 words it is allowed only while it fits
  /// at standard spacing — it may fill free space, never squeeze the page.
  static String? messageFit(int words, TemplateLayout layout) {
    if (words > Limits.messageWords) {
      return layout.bodyFits && !layout.spacingTightened
          ? null
          : Msg.messageNoFreeSpace;
    }
    return layout.bodyFits ? null : Msg.pageFull;
  }

  /// Error for one Further Study entry, or null when acceptable.
  static String? furtherStudyEntry(String entry) {
    final value = entry.trim();
    if (value.isEmpty) return null;
    if (value.length > Limits.furtherStudyRefChars) {
      return Msg.furtherStudyChars;
    }
    if (countWords(value) > Limits.furtherStudyRefWords) {
      return Msg.furtherStudyRefOnly;
    }
    if (!isBibleReference(value)) return Msg.furtherStudyInvalid;
    return null;
  }

  /// The final check before a Daily Juice may be generated.
  static List<Issue> forGeneration({
    required DailyJuice juice,
    required TemplateLayout layout,
    required bool hasPhoto,
  }) {
    final issues = <Issue>[
      ...profile(
        name: juice.authorName,
        surname: juice.authorSurname,
        hasPhoto: hasPhoto,
      ),
    ];
    void add(JuiceField f, String m) => issues.add(Issue(f, m));

    final title = juice.title.trim();
    if (title.isEmpty) {
      add(JuiceField.title, Msg.titleRequired);
    } else if (countWords(title) > Limits.titleWords) {
      add(JuiceField.title, Msg.titleWords);
    } else if (title.length > Limits.titleChars) {
      add(JuiceField.title, Msg.titleChars);
    } else if (!layout.titleFits) {
      add(JuiceField.title, Msg.titleWidth);
    }

    final scripture = juice.themeScripture.trim();
    if (countWords(scripture) == 0) {
      add(JuiceField.scripture, Msg.scriptureRequired);
    } else if (countWords(scripture) > Limits.scriptureWords) {
      add(JuiceField.scripture, Msg.scriptureWords);
    }

    final reference = juice.scriptureReference.trim();
    if (reference.isEmpty) {
      add(JuiceField.scriptureReference, Msg.scriptureReferenceRequired);
    } else if (reference.length > Limits.scriptureReferenceChars) {
      add(JuiceField.scriptureReference, Msg.scriptureReferenceChars);
    } else if (!isBibleReference(
      reference.replaceAll(RegExp(r'^\(|\)$'), ''),
    )) {
      add(JuiceField.scriptureReference, Msg.scriptureReferenceInvalid);
    }

    final words = countWords(juice.mainMessage);
    if (words == 0) {
      add(JuiceField.message, Msg.messageRequired);
    } else {
      final error = messageFit(words, layout);
      if (error != null) add(JuiceField.message, error);
    }

    final refs = juice.furtherStudy
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    if (refs.isEmpty) {
      add(JuiceField.furtherStudy, Msg.furtherStudyRequired);
    } else if (refs.length > Limits.furtherStudyRefs) {
      add(JuiceField.furtherStudy, Msg.furtherStudyMax);
    } else {
      for (final r in refs) {
        final error = furtherStudyEntry(r);
        if (error != null) {
          add(JuiceField.furtherStudy, '“$r”: $error');
        }
      }
      if (!layout.furtherStudyFits) {
        add(JuiceField.furtherStudy, Msg.furtherStudyWidth);
      }
    }
    return issues;
  }
}
