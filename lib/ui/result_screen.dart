
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../core/download.dart';
import '../core/juice_date.dart';
import '../core/validation.dart';
import '../models/daily_juice.dart';
import '../template/template_layout.dart';
import '../template/template_painter.dart';
import '../template/template_spec.dart';
import 'editor_screen.dart';
import 'theme.dart';
import 'widgets/juice_preview.dart';

/// The finished Daily Juice: rendered at full resolution, ready to export.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.juiceId});

  final String juiceId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final AppState _state = AppScope.read(context);
  DailyJuice? _juice;
  Uint8List? _png;
  String? _path;
  List<Issue> _issues = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final juice = _state.juice(widget.juiceId);
    if (juice == null) {
      setState(() => _error = 'This Daily Juice could not be found.');
      return;
    }
    try {
      final photo = await _state.image(juice.profileImagePath);
      final layout = TemplateLayoutEngine.compute(juice.toContent());
      // Final safety check: never export an incomplete or overflowing page.
      final issues = Validation.forGeneration(
        juice: juice,
        layout: layout,
        hasPhoto: photo != null,
      );
      if (issues.isNotEmpty) {
        setState(() {
          _juice = juice;
          _issues = issues;
        });
        return;
      }
      // Reuse the image already generated for this exact version.
      final previous = await _state.repo.readCurrentExport(juice);
      if (previous != null) {
        if (!mounted) return;
        setState(() {
          _juice = juice;
          _png = previous;
          _path = juice.exportPath;
        });
        return;
      }
      final png = await TemplatePainter.renderPng(
        layout,
        photo: photo,
        crop: juice.profileImageCrop,
      );
      final path = await _state.repo.saveExport(juice, png);
      await _state.saveJuice(juice.copyWith(exportPath: path));
      if (!mounted) return;
      setState(() {
        _juice = juice;
        _png = png;
        _path = path;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'The image could not be created: $e');
      }
    }
  }

  String get _fileName {
    final j = _juice!;
    final slug = j.title
        .trim()
        .replaceAll(RegExp(r"[^\p{L}\p{N}]+", unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'Daily-Juice_${toIsoDate(j.date)}${slug.isEmpty ? '' : '_$slug'}';
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _download(Uint8List png) {
    downloadFile(png, '$_fileName.png', 'image/png');
    _snack('Downloaded $_fileName.png.');
  }

  /// Web version on an iPhone: Safari can only put images in Photos through
  /// the share sheet ("Save Image").
  static bool get _iPhoneWeb =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _saveToGallery(BuildContext button) async {
    final png = _png;
    if (png == null) return;
    if (_iPhoneWeb) return _share(button);
    if (kIsWeb) {
      _download(png);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(png, album: 'The Daily Juice', name: _fileName);
      _snack('Saved to your gallery in the “The Daily Juice” album.');
    } on GalException catch (e) {
      _snack('Could not save to the gallery: ${e.type.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// [button] anchors the share sheet (required on iPad).
  Future<void> _share(BuildContext button) async {
    final png = _png;
    final path = _path;
    if (png == null || (!kIsWeb && path == null)) return;
    final box = button.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            kIsWeb
                ? XFile.fromData(
                    png,
                    mimeType: 'image/png',
                    name: '$_fileName.png',
                  )
                : XFile(path!, mimeType: 'image/png'),
          ],
          fileNameOverrides: ['$_fileName.png'],
          title: 'The Daily Juice',
          sharePositionOrigin: origin,
        ),
      );
      // Browsers without file sharing (most computers) download it instead.
      if (kIsWeb && result.status == ShareResultStatus.unavailable) {
        _download(png);
      }
    } catch (e) {
      if (kIsWeb) {
        _download(png);
      } else {
        _snack('Could not open sharing: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit() {
    final juice = _juice ?? _state.juice(widget.juiceId);
    if (juice == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EditorScreen(initial: juice)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOUR DAILY JUICE'),
        actions: [
          TextButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('EDIT'),
          ),
        ],
      ),
      body: _error != null
          ? _message(_error!)
          : _issues.isNotEmpty
          ? _message(
              'This Daily Juice needs corrections before it can be '
              'generated:\n\n${_issues.map((i) => '• ${i.message}').join('\n')}',
              showEdit: true,
            )
          : png == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Generating your Daily Juice…'),
                ],
              ),
            )
          : ColoredBox(
              color: const Color(0xFFE2E0DC),
              child: ZoomablePreview(
                child: AspectRatio(
                  aspectRatio: TemplateSpec.width / TemplateSpec.height,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.memory(
                      png,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: png == null
          ? null
          : Material(
              color: Colors.white,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (button) => OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _saveToGallery(button),
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('SAVE'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Builder(
                              builder: (button) => FilledButton.icon(
                                onPressed:
                                    _busy ? null : () => _share(button),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('SHARE'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _iPhoneWeb
                            ? 'Tip: tap SAVE, then “Save Image” to add it to '
                                  'Photos. On WhatsApp, attach it as a '
                                  'Document to keep full quality.'
                            : 'Tip: on WhatsApp, attach it as a Document to '
                                  'keep full quality.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Brand.muted, fontSize: 12),
                      ),
                      Text(
                        '${TemplateSpec.width.toInt()} × '
                        '${TemplateSpec.height.toInt()} px PNG · A4 at 300 dpi · '
                        '${(png.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _message(String text, {bool showEdit = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
          if (showEdit) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: _edit, child: const Text('EDIT')),
          ],
        ],
      ),
    ),
  );
}
