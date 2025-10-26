import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../services/purchase_service.dart';
import '../widgets/ad_banner.dart';
import 'home_screen.dart';
import 'bible_reader_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; // Começar na aba "Jogar" (Home)
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateToReader: () => _navigateToTab(1)), // Tela principal do jogo
      const BibleReaderScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner de anúncio apenas para usuários não-PRO
              Consumer<PurchaseService>(
                builder: (context, purchaseService, _) {
                  if (purchaseService.isProVersion) return const SizedBox.shrink();
                  return const SafeArea(
                    top: false,
                    child: AdBanner(),
                  );
                },
              ),
              // Bottom Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: themeManager.surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onTabTapped,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: themeManager.surfaceColor,
                    selectedItemColor: themeManager.primaryColor,
                    unselectedItemColor: themeManager.secondaryTextColor,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                    elevation: 0,
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.quiz_outlined),
                        activeIcon: Icon(Icons.quiz),
                        label: 'Jogar',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.menu_book_outlined),
                        activeIcon: Icon(Icons.menu_book),
                        label: 'Ler',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.bar_chart_outlined),
                        activeIcon: Icon(Icons.bar_chart),
                        label: 'Estatísticas',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.settings_outlined),
                        activeIcon: Icon(Icons.settings),
                        label: 'Configurações',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}