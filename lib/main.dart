import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/purchase_service.dart';
import 'providers/game_provider.dart';
import 'services/themes/theme_manager.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/database_initialization_screen.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Iniciando aplicação Bible Quiz...');

  // Respeitar configuração de manter tela ligada ao abrir o app
  final prefs = await SharedPreferences.getInstance();
  final keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
  if (keepScreenOn) {
    WakelockPlus.enable();
  } else {
    WakelockPlus.disable();
  }

  // Inicializa Google Mobile Ads
  await MobileAds.instance.initialize();

  // Inicializa compras e status PRO antes do ThemeManager
  final purchaseService = PurchaseService();
  await purchaseService.loadPurchaseStatusSync();

  // Inicializar ThemeManager com status PRO real
  final themeManager = ThemeManager();
  themeManager.setPremiumStatusSync(purchaseService.isProVersion);
  await themeManager.init();

  runApp(MyApp(themeManager: themeManager, purchaseService: purchaseService));
}

class MyApp extends StatefulWidget {
  final ThemeManager themeManager;
  final PurchaseService purchaseService;
  
  const MyApp({super.key, required this.themeManager, required this.purchaseService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDatabaseInitialized = false;
  bool _isCheckingDatabase = true;

  @override
  void initState() {
    super.initState();
    _checkDatabaseInitialization();
  }

  Future<void> _checkDatabaseInitialization() async {
    try {
      // Verificar se o banco já foi inicializado
      final dbHelper = DatabaseHelper();
      
      // Se não der erro, está inicializado
      await dbHelper.gameManager;
      // ignore: unused_local_variable
      
      setState(() {
        _isDatabaseInitialized = true;
        _isCheckingDatabase = false;
      });
    } catch (e) {
      // Se der erro, precisa inicializar
      setState(() {
        _isDatabaseInitialized = false;
        _isCheckingDatabase = false;
      });
    }
  }

  void _onDatabaseInitializationComplete() {
    setState(() {
      _isDatabaseInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GameProvider()),
        ChangeNotifierProvider.value(value: widget.themeManager),
        ChangeNotifierProvider.value(value: widget.purchaseService),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'BookQuest',
            debugShowCheckedModeBanner: false,
            theme: themeManager.currentTheme.toThemeData().copyWith(
              // Personalização adicional para o app bíblico - teste
              textTheme: themeManager.currentTheme.toThemeData().textTheme.copyWith(
                headlineLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
                headlineMedium: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                titleLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                bodyLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontSize: 16,
                ),
                bodyMedium: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontSize: 14,
                ),
                bodySmall: TextStyle(
                  color: themeManager.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ),
            home: _isCheckingDatabase
                ? Scaffold(
                    backgroundColor: themeManager.backgroundColor,
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          themeManager.primaryColor,
                        ),
                      ),
                    ),
                  )
                : !_isDatabaseInitialized
                    ? DatabaseInitializationScreen(
                        onComplete: _onDatabaseInitializationComplete,
                      )
                    : Consumer<GameProvider>(
                        builder: (context, gameProvider, child) {
                          // Sincroniza tema com mudanças do PRO em tempo real
                          context.select<PurchaseService, bool>((ps) => ps.isProVersion);
                          themeManager.syncWithPurchaseService(context.read<PurchaseService>().isProVersion);
                          // Aguardar inicialização do provider
                          if (gameProvider.gameState == GameState.loading) {
                            return Scaffold(
                              backgroundColor: themeManager.backgroundColor,
                              body: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        themeManager.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Carregando...',
                                      style: TextStyle(
                                        color: themeManager.primaryTextColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          return gameProvider.hasPlayerName 
                              ?  const MainNavigationScreen()
                              :  WelcomeScreen();
                        },
                      ),
          );
        },
      ),
    );
  }
}
