import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import 'main_navigation_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) => Scaffold(
        backgroundColor: themeManager.backgroundColor,
        body: SafeArea(
          child: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 80,
                        color: themeManager.primaryColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.sessionComplete,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: themeManager.primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Parabéns por completar mais uma sessão!',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: themeManager.secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Estatísticas da sessão
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: themeManager.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Seus Resultados',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: themeManager.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatItem(
                                  label: AppStrings.score,
                                  value: gameProvider.score.toString(),
                                  icon: Icons.stars,
                                  color: themeManager.primaryColor,
                                ),
                                _StatItem(
                                  label: 'Corretas',
                                  value: gameProvider.correctAnswers.toString(),
                                  icon: Icons.check_circle,
                                  color: themeManager.primaryColor,
                                  // suaviza a cor verde
                                ),
                                _StatItem(
                                  label: 'Streak',
                                  value: gameProvider.currentStreak.toString(),
                                  icon: Icons.whatshot,
                                  color: themeManager.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botões
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final gameProvider = context.read<GameProvider>();
                                await gameProvider.reloadStats(force: true);
                                // Limpar estado do jogo e garantir retorno ao menu
                                gameProvider.backToMenu();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                                  (route) => false,
                                );
                              },
                              icon: const Icon(Icons.home),
                              label: const Text('Voltar ao Menu'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeManager.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: themeManager.secondaryTextColor,
              ),
            ),
          ],
        );
      },
    );
  }
}
