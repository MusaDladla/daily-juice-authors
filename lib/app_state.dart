import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'data/juice_repository.dart';
import 'models/daily_juice.dart';
import 'models/profile.dart';

/// App-wide state: the author's profile, their Daily Juices, and decoded
/// photos.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final JuiceRepository repo;

  Profile? profile;
  List<DailyJuice> juices = const [];
  final Map<String, ui.Image> _images = {};

  Future<void> load() async {
    profile = await repo.loadProfile();
    juices = await repo.listJuices();
    notifyListeners();
  }

  DailyJuice? juice(String id) {
    for (final j in juices) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// The decoded photo if it is already cached, without waiting.
  ui.Image? peekImage(String path) => _images[path];

  /// Decodes (and caches) a stored photo at full resolution.
  Future<ui.Image?> image(String path) async {
    if (path.isEmpty) return null;
    final cached = _images[path];
    if (cached != null) return cached;
    final bytes = await repo.readImage(path);
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    return _images[path] = image;
  }

  Future<void> saveProfile(Profile p) async {
    await repo.saveProfile(p);
    profile = p;
    notifyListeners();
    await repo.deleteUnusedPhotos();
  }

  Future<void> saveJuice(DailyJuice j) async {
    await repo.saveJuice(j);
    final list = [...juices.where((e) => e.id != j.id), j];
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
    });
    juices = list;
    notifyListeners();
  }

  Future<void> deleteJuice(DailyJuice j) async {
    await repo.deleteJuice(j);
    juices = juices.where((e) => e.id != j.id).toList();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
