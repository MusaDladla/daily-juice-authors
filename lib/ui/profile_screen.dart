import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../core/limits.dart';
import '../core/validation.dart';
import '../data/juice_repository.dart';
import '../models/profile.dart';
import '../template/photo_crop.dart';
import '../template/template_layout.dart';
import '../template/template_spec.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'widgets/brand.dart';
import 'widgets/focus_preview.dart';
import 'widgets/form_parts.dart';
import 'widgets/photo_framer.dart';

/// Create (first run) or edit the author profile.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _branch = TextEditingController();

  ui.Image? _photo;
  Uint8List? _newPhotoBytes;
  PhotoCrop _crop = const PhotoCrop();
  bool _loadingPhoto = false;
  bool _saving = false;
  bool _attempted = false;
  List<Issue> _issues = const [];

  // What the profile looked like when the screen opened, to detect edits.
  String _initialName = '';
  String _initialSurname = '';
  String _initialBranch = '';
  PhotoCrop _initialCrop = const PhotoCrop();

  /// Set once the author saved or chose to discard, so leaving is allowed.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    if (p != null) {
      _name.text = p.name;
      _surname.text = p.surname;
      _branch.text = p.branch;
      _crop = p.photoCrop;
      _initialName = p.name;
      _initialSurname = p.surname;
      _initialBranch = p.branch;
      _initialCrop = p.photoCrop;
      AppScope.read(context).image(p.photoPath).then((img) {
        if (mounted) setState(() => _photo = img);
      });
    }
    for (final c in [_name, _surname, _branch]) {
      c.addListener(_revalidate);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _branch.dispose();
    super.dispose();
  }

  List<Issue> _validate() => Validation.profile(
    name: _name.text,
    surname: _surname.text,
    hasPhoto: _photo != null,
  );

  void _revalidate() => setState(() {
    if (_attempted) _issues = _validate();
  });

  String? _errorFor(JuiceField f) {
    for (final i in _issues) {
      if (i.field == f) return i.message;
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _loadingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      setState(() {
        _photo = image;
        _newPhotoBytes = bytes;
        _crop = PhotoCrop.auto(
          Size(image.width.toDouble(), image.height.toDouble()),
          TemplateSpec.photo.size,
        );
      });
      _revalidate();
    } on PlatformException catch (e) {
      _snack('Could not open the photo: ${e.message ?? e.code}');
    } catch (_) {
      _snack('That file could not be used as a photo. Please choose another.');
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  /// Whether anything differs from the saved profile.
  bool get _hasChanges =>
      _name.text.trim() != _initialName.trim() ||
      _surname.text.trim() != _initialSurname.trim() ||
      _branch.text.trim() != _initialBranch.trim() ||
      _newPhotoBytes != null ||
      _crop != _initialCrop;

  /// Leaving with unsaved changes: save and exit, or discard and exit.
  Future<void> _confirmLeave() async {
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save your changes?'),
        content: Text(
          widget.firstRun
              ? 'Your profile has not been saved yet.'
              : 'You have changed your profile but not saved it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Brand.error),
            child: const Text('Discard and exit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle: Brand.heading(16, color: Colors.white),
            ),
            child: const Text('SAVE AND EXIT'),
          ),
        ],
      ),
    );
    if (!mounted || save == null) return; // dismissed: keep editing
    if (save) {
      await _save();
      return;
    }
    setState(() => _leaving = true);
    if (widget.firstRun) {
      await SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _attempted = true;
      _issues = _validate();
    });
    if (_issues.isNotEmpty) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    try {
      final existing = state.profile;
      var photoPath = existing?.photoPath ?? '';
      final newBytes = _newPhotoBytes;
      if (newBytes != null) photoPath = await state.repo.storePhoto(newBytes);
      final now = DateTime.now();
      final profile = Profile(
        id: existing?.id ?? JuiceRepository.newId(),
        name: _name.text.trim(),
        surname: _surname.text.trim(),
        branch: _branch.text.trim(),
        photoPath: photoPath,
        photoCrop: _crop,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await state.saveProfile(profile);
      if (!mounted) return;
      _leaving = true;
      if (widget.firstRun) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pop();
        _snack('Profile saved.');
      }
    } catch (e) {
      _snack('Your profile could not be saved: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '${_name.text.trim()} ${_surname.text.trim()}'.trim();
    final photo = _photo;
    return PopScope(
      canPop: _leaving || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.firstRun ? 'CREATE YOUR PROFILE' : 'YOUR PROFILE'),
          automaticallyImplyLeading: !widget.firstRun,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            children: [
              if (widget.firstRun) ...[
                const _WelcomeBanner(),
                const SizedBox(height: 14),
              ] else ...[
                const Text(
                  'Changes apply to new Daily Juices and to drafts. Daily '
                  'Juices you already generated keep the details they were '
                  'made with until you edit them.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Brand.muted,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SectionCard(
                title: 'Profile photo',
                complete: photo != null,
                subtitle: photo == null
                    ? 'Required. Choose a clear photo of your face.'
                    : 'Drag the photo, or use the arrows to move it up, down, '
                          'left and right. Use the slider to zoom.',
                child: Column(
                  children: [
                    if (_loadingPhoto)
                      const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (photo == null)
                      Center(
                        child: SizedBox(
                          width: 190,
                          child: _PhotoPlaceholder(
                            onTap: () => _pickPhoto(ImageSource.gallery),
                          ),
                        ),
                      )
                    else
                      PhotoFramer(
                        image: photo,
                        crop: _crop,
                        onChanged: (c) => setState(() => _crop = c),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loadingPhoto
                              ? null
                              : () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            photo == null ? 'CHOOSE PHOTO' : 'CHANGE',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loadingPhoto
                              ? null
                              : () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('TAKE PHOTO'),
                        ),
                      ],
                    ),
                    FieldMessage(_errorFor(JuiceField.profileImage)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Your details',
                complete:
                    _name.text.trim().isNotEmpty &&
                    _surname.text.trim().isNotEmpty,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(_name, 'Name *', JuiceField.name, Limits.nameChars),
                    const SizedBox(height: 12),
                    _field(
                      _surname,
                      'Surname *',
                      JuiceField.surname,
                      Limits.nameChars,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _branch,
                      'Youth For Christ branch (optional)',
                      JuiceField.branch,
                      Limits.branchChars,
                      action: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              if (photo != null || fullName.isNotEmpty) ...[
                const SizedBox(height: 14),
                SectionCard(
                  title: 'On your Daily Juice',
                  subtitle: 'Your photo and name, exactly as they will appear.',
                  child: _HeaderPreview(
                    fullName: fullName,
                    photo: photo,
                    crop: _crop,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SAVE PROFILE'),
              ),
              const YfcFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    JuiceField field,
    int maxChars, {
    TextInputAction action = TextInputAction.next,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        textInputAction: action,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxChars),
          FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
        ],
        decoration: InputDecoration(labelText: label),
      ),
      FieldMessage(_errorFor(field)),
    ],
  );
}

/// The real template header with the author's photo and name.
class _HeaderPreview extends StatelessWidget {
  const _HeaderPreview({
    required this.fullName,
    required this.photo,
    required this.crop,
  });

  final String fullName;
  final ui.Image? photo;
  final PhotoCrop crop;

  @override
  Widget build(BuildContext context) {
    final layout = TemplateLayoutEngine.compute(
      TemplateContent(
        authorFullName: fullName,
        title: 'Your title',
        date: DateTime.now(),
        scripture: '',
        scriptureReference: '',
        message: '',
        furtherStudy: const [],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FocusPreview(
          layout: layout,
          photo: photo,
          crop: crop,
          focus: PreviewFocus.header,
          height: c.maxWidth * 700 / TemplateSpec.width,
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      color: Brand.charcoal,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: StripePainter(color: Color(0x14FFFFFF)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME TO DAILY JUICE AUTHORS',
                  style: Brand.heading(24, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  Ministry.tagline,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                const ReachPill(),
                const SizedBox(height: 14),
                const Text(
                  'Set up your profile once. Your photo and name are '
                  'placed on every Daily Juice you write.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: TemplateSpec.photo.width / TemplateSpec.photo.height,
    child: Material(
      color: const Color(0xFFEDEBE8),
      child: InkWell(
        onTap: onTap,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 44, color: Brand.muted),
            SizedBox(height: 8),
            Text('Add photo', style: TextStyle(color: Brand.muted)),
          ],
        ),
      ),
    ),
  );
}
