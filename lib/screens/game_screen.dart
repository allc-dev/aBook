import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/themes/theme_manager.dart';
import '../providers/game_provider.dart';
import '../widgets/chapter_modal.dart';
import '../widgets/verse_hint_modal.dart';
import 'results_screen.dart';
import 'main_navigation_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final gameProvider = context.read<GameProvider>();
    if (state == AppLifecycleState.paused) {
      gameProvider.pauseGame();
    } else if (state == AppLifecycleState.resumed) {
      gameProvider.resumeGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false; // Impede pop automático, mostra dialog
      },
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, _) => Scaffold(
          backgroundColor: themeManager.backgroundColor,
          body: SafeArea(
            child: Consumer2<GameProvider, ThemeManager>(
              builder: (context, gameProvider, themeManager, child) {
                // estados iniciais / fim de jogo
                if (gameProvider.gameState == GameState.loading) {
                  return _LoadingView(key: const ValueKey('loading_v2'), themeManager: themeManager);
                }
                if (gameProvider.gameState == GameState.sessionEnded ||
                    gameProvider.gameState == GameState.gameOver) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ResultsScreen()),
                    );
                  });
                  return _LoadingView(themeManager: themeManager);
                }
                if (gameProvider.currentQuestion == null) {
                  return _NoQuestionView(themeManager: themeManager);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra de status com cor primária
                    _GameHeader(themeManager: themeManager, usePrimaryColor: true),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.04, 0),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          // Bloco único: pergunta + respostas
                          child: _QuestionAndAlternativesBlock(
                            key: ValueKey(gameProvider.currentQuestionIndex),
                            themeManager: themeManager,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do Jogo'),
        content:
            const Text('Tem certeza que deseja sair? Seu progresso será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // fecha o diálogo
              final gameProvider = context.read<GameProvider>();
              gameProvider.backToMenu();
              // Garante retorno à tela principal limpando a pilha até MainNavigationScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ===================== Loading =====================
class _LoadingView extends StatefulWidget {
  final ThemeManager themeManager;
  const _LoadingView({super.key, required this.themeManager});

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _textController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  
  final List<String> _loadingMessages = [
    'Preparando o quiz...',
    'Sorteando as questões...',
    'Vamos embaralhar mais um pouco...',
    'Ajustando dificuldade...',
    'Opa, agora tá quase pronto...',
    'Últimos ajustes...'
  ];

  @override
  void initState() {
    super.initState();
    
    // Configurar animação de rotação
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    // Configurar animação de fade do texto
    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));
    
    // Iniciar animações
    _rotationController.repeat();
    _textController.forward();
    
    // Timer para trocar mensagens
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (mounted) {
        _textController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
            });
            _textController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _textController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.themeManager.backgroundColor.withOpacity(0.95),
            widget.themeManager.backgroundColor,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: widget.themeManager.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.themeManager.primaryColor.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: widget.themeManager.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de progresso melhorado
              Stack(
                alignment: Alignment.center,
                children: [
                  // Círculo de fundo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.themeManager.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  // Indicador rotativo
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value * 2 * 3.14159,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                widget.themeManager.primaryColor,
                                widget.themeManager.primaryColor.withOpacity(0.1),
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Ícone central
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.themeManager.backgroundColor,
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      size: 28,
                      color: widget.themeManager.primaryColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Mensagem animada melhorada
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _fadeAnimation.value)),
                      child: Column(
                        children: [
                          Text(
                            _loadingMessages[_currentMessageIndex],
                            style: TextStyle(
                              fontSize: 18,
                              color: widget.themeManager.primaryTextColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Aguarde um momento...",
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.themeManager.secondaryTextColor,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Barra de progresso animada
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: widget.themeManager.primaryColor.withOpacity(0.1),
                ),
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.3 + (0.7 * _rotationAnimation.value),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              widget.themeManager.primaryColor.withOpacity(0.5),
                              widget.themeManager.primaryColor,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Pontos de progresso melhorados
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = (_currentMessageIndex % 4) == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 12 : 8,
                    height: isActive ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? widget.themeManager.primaryColor
                          : widget.themeManager.primaryColor.withOpacity(0.3),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: widget.themeManager.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== No Question =====================
class _NoQuestionView extends StatelessWidget {
  final ThemeManager themeManager;
  const _NoQuestionView({required this.themeManager});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 80, color: themeManager.incorrectColor),
        const SizedBox(height: 16),
        Text(
          'Nenhuma pergunta disponível',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: themeManager.primaryTextColor,
          ),
        ),
      ]),
    );
  }
}

// ===================== Header =====================
class _GameHeader extends StatelessWidget {
  final ThemeManager themeManager;
  final bool usePrimaryColor;
  const _GameHeader({required this.themeManager, this.usePrimaryColor = false});

  String _livesLabel(BuildContext context) {
    final gp = context.read<GameProvider>();
    final diff = gp.currentSession?.difficultyLevel.toLowerCase();
    if (diff == 'fácil') return '∞';
    return gp.lives.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: themeManager.surfaceColor.withOpacity(0.98),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Consumer<GameProvider>(
        builder: (context, gp, child) {
          // Cores para cada ícone
          final timerColor = gp.timeRemaining <= 5
              ? themeManager.incorrectColor
              : Colors.amber[800]!;
          final progressColor = Colors.blueGrey[600]!;
          final scoreColor = Colors.amber[700]!;
          final streakColor = Colors.green[600]!;
          final livesColor = Colors.red[600]!;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerPill(
                icon: Icons.timer,
                text: '${gp.timeRemaining}s',
                color: timerColor,
                bg: timerColor.withOpacity(0.10),
              ),
              _headerPill(
                icon: Icons.quiz,
                text: '${gp.currentQuestionIndex + 1}/${gp.questionsPerSession}',
                color: progressColor,
                bg: progressColor.withOpacity(0.08),
              ),
              _headerPill(
                icon: Icons.stars,
                text: gp.score.toString(),
                color: scoreColor,
                bg: scoreColor.withOpacity(0.10),
              ),
              _headerPill(
                icon: Icons.whatshot,
                text: gp.currentStreak.toString(),
                color: streakColor,
                bg: streakColor.withOpacity(0.10),
              ),
              _headerPill(
                icon: Icons.favorite,
                text: _livesLabel(context),
                color: livesColor,
                bg: livesColor.withOpacity(0.10),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerPill({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg, // ignorado
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
      ],
    );
  }
}

// ===================== Bloco Único: Pergunta + Alternativas =====================
class _QuestionAndAlternativesBlock extends StatelessWidget {
  final ThemeManager themeManager;
  const _QuestionAndAlternativesBlock({super.key, required this.themeManager});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(builder: (context, gp, child) {
      final question = gp.currentQuestion!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: themeManager.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: themeManager.primaryColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pergunta centralizada, sem bloco de capítulo/versículo
            Text(
              question.verse.text,
              style: TextStyle(
                fontSize: 19,
                height: 1.5,
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.04), offset: const Offset(0.5, 0.5), blurRadius: 2)
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Consumer<GameProvider>(
              builder: (context, gp, child) {
                final question = gp.currentQuestion!;
                final isAnswered = gp.gameState == GameState.questionAnswered;
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isAnswered) {
                            showChapterModal(
                              context: context,
                              bookName: question.verse.bookName ?? '',
                              chapter: question.verse.chapter,
                              highlightVerse: question.verse.verse,
                            );
                          } else {
                            if (question.verse.bookName != null && 
                                question.verse.chapter > 0 && 
                                question.verse.verse > 0) {
                              showVerseHintModal(
                                context: context,
                                bookName: question.verse.bookName!,
                                chapter: question.verse.chapter,
                                centerVerse: question.verse.verse,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dica não disponível para esta pergunta'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              print('❌ Dados inválidos para dica: bookName=${question.verse.bookName}, chapter=${question.verse.chapter}, verse=${question.verse.verse}');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAnswered 
                              ? themeManager.primaryColor.withOpacity(0.9)
                              : themeManager.secondaryColor.withOpacity(0.9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          minimumSize: const Size(0, 26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAnswered ? Icons.menu_book : Icons.lightbulb_outline,
                              size: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAnswered ? 'Ver' : 'Dica',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _AlternativesSection(themeManager: themeManager),
          ],
        ),
      );
    });
  }
}

// ===================== Alternatives =====================
class _AlternativesSection extends StatelessWidget {
  final ThemeManager themeManager;
  const _AlternativesSection({required this.themeManager});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(builder: (context, gp, child) {
      final question = gp.currentQuestion!;
      final isAnswered = gp.gameState == GameState.questionAnswered;
      final alternatives = gp.shuffledAlternatives;
      final isGameOver = gp.remainingLives <= 0 || !gp.hasMoreQuestions;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...alternatives.asMap().entries.map((entry) {
            final index = entry.key;
            final alternative = entry.value;
            final isSelected = gp.selectedAlternativeIndex == index;
            final isCorrect = alternative == question.correctAnswer;

            // Cores dinâmicas e feedback visual
            Color bg = themeManager.surfaceColor;
            Color border = themeManager.primaryColor.withOpacity(0.30);
            Color textColor = themeManager.primaryTextColor;
            IconData? feedbackIcon;
            Color? feedbackIconColor;

            if (isAnswered) {
              if (isCorrect) {
                bg = themeManager.correctColor.withOpacity(0.13);
                border = themeManager.correctColor;
                textColor = themeManager.correctColor;
                feedbackIcon = Icons.check_circle;
                feedbackIconColor = themeManager.correctColor;
              } else if (isSelected && !isCorrect) {
                bg = themeManager.incorrectColor.withOpacity(0.13);
                border = themeManager.incorrectColor;
                textColor = themeManager.incorrectColor;
                feedbackIcon = Icons.cancel;
                feedbackIconColor = themeManager.incorrectColor;
              }
            } else if (isSelected) {
              bg = themeManager.primaryColor.withOpacity(0.13);
              border = themeManager.primaryColor;
              textColor = themeManager.primaryColor;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 2.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 4))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isAnswered ? null : () => gp.selectAlternative(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                      child: Row(
                        children: [
                          if (isAnswered && feedbackIcon != null)
                            Icon(feedbackIcon, color: feedbackIconColor, size: 24)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              alternative,
                              style: TextStyle(
                                fontSize: 17,
                                color: textColor,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          Padding(
            padding: EdgeInsets.only(top: (!isAnswered && gp.selectedAlternativeIndex == null) ? 30 : 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: !isAnswered && gp.selectedAlternativeIndex == null
                    ? null
                    : () => isAnswered ? gp.goToNextQuestion() : gp.confirmAnswer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
                child: Text(
                  isAnswered
                      ? (isGameOver ? 'Ver Resultados' : 'Próximo')
                      : 'Confirmar',
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
