import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:today/helpers/database.dart';
import 'package:today/helpers/notification.dart';
import 'package:today/repository/activity_repository.dart';
import 'package:today/screens/help_screen.dart';
import 'package:today/screens/home_screen.dart';
import 'package:today/screens/settings_screen.dart';
import 'package:today/screens/splash_screen.dart';
import 'package:today/services/activity_service.dart';
import 'package:today/stores/app_store.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notif.initializeLocalNotifications();
  await Notif.initializeIsolateReceivePort();
  await dotenv.load(fileName: ".env");

  final appStore = AppStore();
  await appStore.initialize();

  final database = DatabaseHelper();
  final db = await database.db;

  final activityRepo = ActivityRepository(db: db);
  // more repository here...

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => appStore),
      Provider(create: (_) => ActivityService(activityRepo: activityRepo)),
    ],
    child: const App(),
  ));
}

final routes = <String, WidgetBuilder>{
  '/splash': (ctx) => const SplashScreen(),
  '/home': (ctx) => const HomeScreen(),
  '/settings': (ctx) => const SettingsScreen(),
  '/help': (ctx) => const HelpScreen(),
};

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStore>(
      builder: (context, appStore, child) {
        return ShadApp(
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: ShadColorScheme.fromName('zinc'),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme:
                ShadColorScheme.fromName('zinc', brightness: Brightness.dark),
          ),
          themeMode: appStore.theme,
          builder: (context, child) => MaterialApp(
            routes: routes,
            initialRoute: '/splash',
            theme: Theme.of(context),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('id', 'ID'),
              Locale('en', 'US'),
            ],
          ),
        );
      },
    );
  }
}
