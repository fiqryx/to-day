import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:today/helpers/database.dart';
import 'package:today/repository/activity_repository.dart';
import 'package:today/screens/home_screen.dart';
import 'package:today/screens/splash_screen.dart';
import 'package:today/services/activity_service.dart';
import 'package:today/stores/app_store.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<App> {
  DateTime? lastBackPressTime;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_interceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_interceptor);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = <String, WidgetBuilder>{
      '/splash': (ctx) => const SplashScreen(),
      '/home': (ctx) => const HomeScreen(),
    };

    return Consumer<AppStore>(
      builder: (context, appStore, child) {
        return ShadApp.material(
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

  bool _interceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    final now = DateTime.now();

    if (lastBackPressTime == null ||
        now.difference(lastBackPressTime!) > const Duration(seconds: 2)) {
      lastBackPressTime = now;

      if (mounted) {
        Fluttertoast.showToast(
          msg: "Press back again to exit",
          toastLength: Toast.LENGTH_SHORT,
        );
      }

      return true; // intercept/stop the back button
    } else {
      SystemNavigator.pop(); // exit
      return false;
    }
  }
}
