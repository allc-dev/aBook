import 'dart:async';
import 'package:flutter/material.dart';
import '../services/reading_history_service.dart';
import '../models/reading_stats_model.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import 'bible_reader_screen.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToReader;
  
  const HomeScreen({super.key, this.onNavigateToReader});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Jogar',
              style: TextStyle(
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            backgroundColor: themeManager.backgroundColor,
            elevation: 0,
            foregroundColor: themeManager.primaryTextColor,
          ),
          body: SafeArea(
            child: Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                switch (gameProvider.gameState) {
                  case GameState.loading:
                    return _LoadingView();
                  case GameState.canPlay:
                    return _MenuView(
                      onGameFinished: _onGameFinished,
                      onNavigateToReader: widget.onNavigateToReader,
                    );
                  case GameState.error:
                    return _ErrorView(
                      message: gameProvider.errorMessage ?? AppStrings.errorLoadingData,
                      onRetry: () => gameProvider.clearError(),
                    );
                  default:
                    return _MenuView(
                      onGameFinished: _onGameFinished,
                      onNavigateToReader: widget.onNavigateToReader,
                    );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _onGameFinished() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.reloadStats();
    setState(() {});
  }
}

class _LoadingView extends StatelessWidget {
  _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(themeManager.primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Preparando o banco de dados...\nIsso pode levar alguns instantes na primeira vez que você abre o app.',
                style: TextStyle(
                  fontSize: 16,
                  color: themeManager.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Não feche o aplicativo durante este processo.',
                style: TextStyle(
                  fontSize: 13,
                  color: themeManager.secondaryTextColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuView extends StatelessWidget {
  final Future<void> Function()? onGameFinished;
  final VoidCallback? onNavigateToReader;
  
  const _MenuView({this.onGameFinished, this.onNavigateToReader});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Column(
          children: [
            // Conteúdo principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Área de Leitura da Bíblia
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeManager.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book, color: themeManager.primaryColor, size: 28),
                              const SizedBox(width: 8),
                              Text('Leitura da Bíblia', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.bold,
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<ReadingStatsModel>(
                            future: ReadingHistoryService().getReadingStats(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatItem(label: 'Capítulos Lidos', value: '...', icon: Icons.check_circle_outline),
                                    _StatItem(label: 'Dias de Leitura', value: '...', icon: Icons.calendar_today),
                                  ],
                                );
                              }
                              final stats = snapshot.data;
                              final chapters = stats?.totalChaptersRead ?? 0;
                              final days = stats?.totalDaysReading ?? 0;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _StatItem(label: 'Capítulos Lidos', value: '$chapters', icon: Icons.check_circle_outline),
                                  _StatItem(label: 'Dias de Leitura', value: '$days', icon: Icons.calendar_today),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.menu_book),
                              label: const Text('Ler Bíblia'),
                              onPressed: () {
                                if (onNavigateToReader != null) {
                                  onNavigateToReader!();
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const BibleReaderScreen(),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeManager.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Área de Quiz
                    Consumer<GameProvider>(
                      builder: (context, gameProvider, child) {
                        return FutureBuilder<bool>(
                          future: gameProvider.canPlayToday(),
                          builder: (context, snapshot) {
                            final canPlay = snapshot.data ?? true;
                            
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: themeManager.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.quiz, color: themeManager.primaryColor, size: 28),
                                      const SizedBox(width: 8),
                                      Text('Quiz Bíblico', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: themeManager.primaryTextColor,
                                        fontWeight: FontWeight.bold,
                                      )),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (canPlay) ...[
                                    Text(
                                      'Teste seus conhecimentos sobre a Palavra de Deus!',
                                      style: TextStyle(
                                        color: themeManager.secondaryTextColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Jogar Quiz'),
                                        onPressed: () async {
                                          final dialogCompleter = Completer<void>();
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => _QuizLoadingDialog(themeManager: themeManager),
                                          ).then((_) => dialogCompleter.complete());
                                          await gameProvider.startNewSession(gameProvider.defaultDifficulty ?? 'Fácil');
                                          dialogCompleter.future.then((_) {
                                            if (context.mounted) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const GameScreen()),
                                              );
                                            }
                                          });
                                          if (!dialogCompleter.isCompleted) {
                                            Navigator.of(context).pop();
                                            if (context.mounted) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const GameScreen()),
                                              );
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeManager.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          color: themeManager.primaryColor,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Quiz do dia concluído!',
                                          style: TextStyle(
                                            color: themeManager.primaryTextColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Volte amanhã para um novo desafio',
                                          style: TextStyle(
                                            color: themeManager.secondaryTextColor,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Quem Disse Isso? - Em Breve
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeManager.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology, color: themeManager.primaryColor, size: 28),
                              const SizedBox(width: 8),
                              Text('Quem Disse Isso?', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.bold,
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Identifique quem disse famosas frases bíblicas!',
                            style: TextStyle(
                              color: themeManager.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.schedule),
                              label: const Text('Em breve'),
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeManager.primaryColor.withOpacity(0.3),
                                foregroundColor: themeManager.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Linha do Tempo Bíblica - Em Breve
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeManager.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timeline, color: themeManager.primaryColor, size: 28),
                              const SizedBox(width: 8),
                              Text('Linha do Tempo Bíblica', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.bold,
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Organize eventos bíblicos na ordem cronológica correta!',
                            style: TextStyle(
                              color: themeManager.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.schedule),
                              label: const Text('Em breve'),
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeManager.primaryColor.withOpacity(0.3),
                                foregroundColor: themeManager.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const SizedBox(height: 100), // Espaço para o bottom navigation
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Column(
          children: [
            Icon(icon, color: themeManager.primaryColor, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: themeManager.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: themeManager.incorrectColor,
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.error,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: themeManager.primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: themeManager.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeManager.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Modal animado e informativo para quiz
class _QuizLoadingDialog extends StatefulWidget {
  final ThemeManager themeManager;
  const _QuizLoadingDialog({required this.themeManager});

  @override
  State<_QuizLoadingDialog> createState() => _QuizLoadingDialogState();
}

class _QuizLoadingDialogState extends State<_QuizLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  int _currentMessage = 0;
  
  final List<String> _messages = [
    'Carregando perguntas...',
    'Preparando desafio...',
    'Montando questões...',
    'Quase pronto!',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _currentMessage = (_currentMessage + 1) % _messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = widget.themeManager;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: themeManager.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: themeManager.primaryColor.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: themeManager.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeManager.primaryColor.withOpacity(0.1),
                  ),
                ),
                RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeManager.primaryColor,
                        width: 3,
                      ),
                      gradient: SweepGradient(
                        colors: [
                          themeManager.primaryColor.withOpacity(0.1),
                          themeManager.primaryColor,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.quiz,
                  color: themeManager.primaryColor,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _messages[_currentMessage],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeManager.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Montando as questões para você se desafiar!',
              style: TextStyle(
                fontSize: 14,
                color: themeManager.secondaryTextColor,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: themeManager.primaryColor.withOpacity(0.1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.3 + 0.7 * (_currentMessage / (_messages.length - 1)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        themeManager.primaryColor.withOpacity(0.5),
                        themeManager.primaryColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}