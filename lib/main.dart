import 'package:flutter/material.dart';

import 'app.dart';
import 'screens/onboarding.dart';
import 'screens/program_view.dart';
import 'screens/progress.dart';
import 'screens/settings.dart';
import 'screens/today.dart';
import 'theme.dart';
import 'update_checker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  runApp(GymFolioApp(model: model));
  model.boot();
}

class GymFolioApp extends StatelessWidget {
  final AppModel model;
  const GymFolioApp({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: model,
      child: MaterialApp(
        title: 'GymFolio',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);

    if (model.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Tone.accent)),
      );
    }

    if (model.loadError != null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Tone.bad, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Could not read your log',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'The file is there but it would not parse. Nothing has been '
                'overwritten — your history is still on the phone. Send this to '
                'whoever is maintaining the app rather than reinstalling.',
                style: TextStyle(color: Tone.dim, height: 1.4),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Text('${model.loadError}',
                    style: const TextStyle(
                        color: Tone.dim, fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: model.boot,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!model.ready) {
      return const Scaffold(body: Center(child: Text('No program loaded')));
    }

    if (!model.state!.onboarded) return const OnboardingScreen();

    return const _Home();
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _tab = 0;
  bool _checkedForUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checkedForUpdate) return;
      _checkedForUpdate = true;
      autoCheck(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      TodayScreen(),
      ProgressScreen(),
      ProgramScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _tab,
          height: 64,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: 'Progress'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Program'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
