import 'package:daily_juice/template/template_layout.dart';

/// The official reference Daily Juice ("Baal Perazim" by Christian Mapitle),
/// transcribed from the template artwork. Used to prove the engine
/// reproduces the reference layout line for line.
final referenceJuice = TemplateContent(
  authorFullName: 'Christian Mapitle',
  title: 'Baal Perazim',
  date: DateTime(2026, 9, 30), // a Wednesday the 30th
  scripture:
      '“So David went to Baal Perazim, and David defeated them there; '
      'and he said, ‘The LORD has broken through my enemies before me, like '
      'a breakthrough of water.’ Therefore he called the name of that place '
      'Baal Perazim.”',
  scriptureReference: '2 Samuel 5:20',
  message: [
    'Baal Perazim is a Hebrew name that translates to “The Master of '
        'Breakthroughs” or “The Lord who breaks forth.” When the Philistines '
        'gathered against David, he did not rely on his own strength. He '
        'inquired of God, received His strategy, and advanced. The Lord broke '
        'through the enemy lines with unstoppable force.',
    'Right after David was anointed king over Israel, the Philistines '
        'gathered to destroy him before his reign could even begin. David '
        "didn't panic; he sought God, and the Lord gave him victory.",
    'No matter how overwhelming the obstacles before you may appear, take '
        'heart! The same God who broke through for David is alive inside you. '
        'When you feel blocked by spiritual opposition, financial stagnation, '
        'or emotional distress, remember that you serve Baal Perazim. He is '
        'still the God of breakthrough.',
    'Challenges will inevitably rise against your faith, health, and family, '
        'but you are never left defenseless. Stand firm in prayer and trust '
        'Him to create a path forward, for “nothing will be impossible with '
        'God” (Luke 1:37).',
  ].join('\n\n'),
  furtherStudy: const ['1 Chronicles 14:11', 'Isaiah 28:21'],
);

/// Line breaks exactly as printed in the reference artwork.
const referenceScriptureLines = [
  '“So David went to Baal Perazim, and David defeated them',
  'there; and he said, ‘The LORD has broken through my',
  'enemies before me, like a breakthrough of water.’ Therefore',
  'he called the name of that place Baal Perazim.”',
];

const referenceBodyLines = [
  'aal Perazim is a Hebrew name that translates to “The',
  'Master of Breakthroughs” or “The Lord who breaks',
  'forth.” When the Philistines gathered against David, he did not',
  'rely on his own strength. He inquired of God, received His',
  'strategy, and advanced. The Lord broke through the enemy',
  'lines with unstoppable force.',
  'Right after David was anointed king over Israel, the Philistines',
  'gathered to destroy him before his reign could even begin.',
  "David didn't panic; he sought God, and the Lord gave him",
  'victory.',
  'No matter how overwhelming the obstacles before you may',
  'appear, take heart! The same God who broke through for David',
  'is alive inside you. When you feel blocked by spiritual',
  'opposition, financial stagnation, or emotional distress,',
  'remember that you serve Baal Perazim. He is still the God of',
  'breakthrough.',
  'Challenges will inevitably rise against your faith, health, and',
  'family, but you are never left defenseless. Stand firm in prayer',
  'and trust Him to create a path forward, for “nothing will be',
  'impossible with God” (Luke 1:37).',
];
