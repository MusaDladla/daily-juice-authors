import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/juice_repository.dart';
import 'ui/home_screen.dart';
import 'ui/profile_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final state = AppState(await JuiceRepository.open());
  await state.load();
  runApp(DailyJuiceApp(state: state));
}

class DailyJuiceApp extends StatelessWidget {
  const DailyJuiceApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: MaterialApp(
      title: 'Daily Juice Authors',
      debugShowCheckedModeBanner: false,
      theme: Brand.theme(),
      // A profile is required before any Daily Juice can be created.
      home: state.profile == null
          ? const ProfileScreen(firstRun: true)
          : const HomeScreen(),
    ),
  );
}
