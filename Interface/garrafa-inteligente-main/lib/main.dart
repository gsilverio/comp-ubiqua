import 'package:flutter/material.dart';
import 'package:garrafa_inteligente/screen/historico/historico_screen.dart';
import 'package:garrafa_inteligente/screen/status/status_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class ScreenSyncService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref(
    "app_state/active_screen",
  );

  Stream<String> get activeScreenStream {
    return _ref.onValue.map((event) {
      return event.snapshot.value?.toString() ?? "";
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ScreenSyncService _syncService = ScreenSyncService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String _currentScreen = '/status';

  @override
  void initState() {
    super.initState();

    _syncService.activeScreenStream.listen((screen) {
      if (screen.isEmpty) return;

      final route = screen == 'historico' ? '/historico' : '/status';

      // Evitar trocar para a mesma tela repetidamente
      if (route != _currentScreen) {
        _currentScreen = route;

        navigatorKey.currentState?.pushReplacementNamed(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const bottleId = 'garrafa-1';

    return MaterialApp(
      title: 'Status da Garrafa',
      navigatorKey: navigatorKey,
      initialRoute: '/status',

      routes: {
        '/status': (context) => const BottleStatusPage(bottleId: bottleId),
        '/historico': (context) =>
            const BottleHistoricoPage(bottleId: bottleId),
      },
    );
  }
}
