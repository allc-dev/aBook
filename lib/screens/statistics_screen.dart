import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../constants/app_strings.dart';
import '../services/verse_quiz_service.dart';
import '../services/reading_history_service.dart';
import '../models/reading_stats_model.dart';
import '../models/reading_history_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final VerseQuizService _quizService = VerseQuizService();
  final ReadingHistoryService _readingService = ReadingHistoryService();
  
  late TabController _tabController;
  Map<String, dynamic>? _quizStats;
  ReadingStatsModel? _readingStats;
  List<ReadingHistoryModel> _recentReadings = [];
  
  bool _isLoadingQuiz = true;
  bool _isLoadingReading = true;
  String? _quizError;
  String? _readingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuizStatistics();
    _loadReadingStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizStatistics() async {
    try {
      final userStats = await _quizService.getUserStats();
      final progress = userStats['progress'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _quizStats = progress;
          _isLoadingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quizError = e.toString();
          _isLoadingQuiz = false;
        });
      }
    }
  }

  Future<void> _loadReadingStatistics() async {
    try {
      final stats = await _readingService.getReadingStats();
      final recent = await _readingService.getRecentReadings(days: 7);
      
      if (mounted) {
        setState(() {
          _readingStats = stats;
          _recentReadings = recent;
          _isLoadingReading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _readingError = e.toString();
          _isLoadingReading = false;
        });
      }
    }
  }

  String _calculateAccuracy(Map<String, dynamic> stats) {
    final totalQuestions = stats['total_questions_answered'] ?? 0;
    final totalCorrect = stats['total_correct_answers'] ?? 0;
    if (totalQuestions == 0) return '0.0%';
    final accuracy = (totalCorrect / totalQuestions) * 100;
    return '${accuracy.toStringAsFixed(1)}%';
  }

  Widget _buildLoadingView(ThemeManager themeManager, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: themeManager.primaryColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: themeManager.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeManager themeManager, String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: themeManager.incorrectColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar estatísticas',
            style: TextStyle(
              color: themeManager.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: themeManager.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeManager.primaryColor,
              foregroundColor: themeManager.backgroundColor,
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeManager themeManager,
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeManager.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: themeManager.primaryTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: themeManager.secondaryTextColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCard(
    ThemeManager themeManager,
    String title,
    IconData icon,
    String summary,
    List<Widget> expandedContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: themeManager.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeManager.primaryColor.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: themeManager.primaryColor),
        title: Text(
          title,
          style: TextStyle(
            color: themeManager.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          summary,
          style: TextStyle(
            color: themeManager.secondaryTextColor,
            fontSize: 12,
          ),
        ),
        iconColor: themeManager.primaryColor,
        collapsedIconColor: themeManager.primaryColor,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: expandedContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) => Scaffold(
        backgroundColor: themeManager.backgroundColor,
        appBar: AppBar(
          title: Text(
            AppStrings.statistics,
            style: TextStyle(color: themeManager.primaryTextColor),
          ),
          backgroundColor: themeManager.backgroundColor,
          elevation: 0,
          foregroundColor: themeManager.primaryTextColor,
          bottom: TabBar(
            controller: _tabController,
            labelColor: themeManager.primaryColor,
            unselectedLabelColor: themeManager.secondaryTextColor,
            indicatorColor: themeManager.primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.auto_stories),
                text: 'Leitura',
              ),
              Tab(
                icon: Icon(Icons.quiz),
                text: 'Quiz',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildReadingStatsView(themeManager),
            _buildQuizStatsView(themeManager),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizStatsView(ThemeManager themeManager) {
    if (_isLoadingQuiz) {
      return _buildLoadingView(themeManager, 'Carregando estatísticas do quiz...');
    }

    if (_quizError != null) {
      return _buildErrorView(themeManager, _quizError!, () {
        setState(() {
          _isLoadingQuiz = true;
          _quizError = null;
        });
        _loadQuizStatistics();
      });
    }

    final stats = _quizStats ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Começe a Jogar!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suas estatísticas do quiz aparecerão aqui após jogar algumas partidas.',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeManager.primaryTextColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          
          // ...removido título de nível e barra de progresso...
          
          const SizedBox(height: 16),

          // Grid de estatísticas
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Total de Sessões',
                      '${stats['total_sessions'] ?? 0}',
                      Icons.calendar_today,
                      Colors.blue[700]!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Total de Pontos (Quiz)',
                      '${(stats['total_points'] ?? 0) - (_readingStats?.totalPointsFromReading ?? 0)}',
                      Icons.stars,
                      Colors.amber[700]!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Melhor Sequência',
                      '${stats['best_streak'] ?? 0}',
                      Icons.emoji_events,
                      Colors.purple[700]!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Sequência Atual',
                      '${stats['current_streak'] ?? 0}',
                      Icons.local_fire_department,
                      Colors.orange[700]!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Total de Perguntas',
                      '${stats['total_questions_answered'] ?? 0}',
                      Icons.quiz,
                      themeManager.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      themeManager,
                      'Respostas Corretas',
                      '${stats['total_correct_answers'] ?? 0}',
                      Icons.check_circle,
                      themeManager.correctColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Precisão geral
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeManager.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeManager.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.track_changes,
                  color: themeManager.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      _calculateAccuracy(stats),
                      style: TextStyle(
                        color: themeManager.primaryTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Precisão Geral',
                      style: TextStyle(
                        color: themeManager.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingStatsView(ThemeManager themeManager) {
    if (_isLoadingReading) {
      return _buildLoadingView(themeManager, 'Carregando estatísticas de leitura...');
    }

    if (_readingError != null) {
      return _buildErrorView(themeManager, _readingError!, () {
        setState(() {
          _isLoadingReading = true;
          _readingError = null;
        });
        _loadReadingStatistics();
      });
    }

    if (_readingStats == null || _readingStats!.totalChaptersRead == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              color: themeManager.secondaryTextColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Ainda não há leituras registradas',
              style: TextStyle(
                color: themeManager.secondaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Comece a ler capítulos da Bíblia para ver suas estatísticas aqui!',
              style: TextStyle(
                color: themeManager.secondaryTextColor.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ...removido título de nível e barra de progresso...
          
          const SizedBox(height: 16),

          // Grid de estatísticas principais reorganizado
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              // Linha 1: Dias de leitura / Pontos ganhos
              _buildStatCard(
                themeManager,
                'Dias de Leitura',
                '${_readingStats!.totalDaysReading}',
                Icons.calendar_today,
                Colors.blue[700]!,
              ),
              _buildStatCard(
                themeManager,
                'Pontos Ganhos',
                '${_readingStats!.totalPointsFromReading}',
                Icons.stars,
                Colors.amber[700]!,
              ),
              // Linha 2: Maior sequência / Sequência atual
              _buildStatCard(
                themeManager,
                'Maior Sequência',
                '${_readingStats!.longestStreak}',
                Icons.workspace_premium,
                Colors.purple[700]!,
              ),
              _buildStatCard(
                themeManager,
                'Sequência Atual',
                '${_readingStats!.currentStreak}',
                Icons.local_fire_department,
                Colors.orange[700]!,
              ),
              // Linha 3: Capítulos lidos / Livros iniciados
              _buildStatCard(
                themeManager,
                'Capítulos Lidos',
                '${_readingStats!.totalChaptersRead}',
                Icons.auto_stories,
                themeManager.primaryColor,
              ),
              _buildStatCard(
                themeManager,
                'Livros Iniciados',
                '${_readingStats!.totalBooksStarted}',
                Icons.library_books,
                Colors.green[700]!,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Livros favoritos (expansível)
          if (_readingStats!.favoriteBooks.isNotEmpty)
            _buildExpandableCard(
              themeManager,
              'Livros Favoritos',
              Icons.favorite,
              _readingStats!.favoriteBooks.take(3).map((book) {
                final chaptersRead = _readingStats!.bookProgress[book] ?? 0;
                return '$book ($chaptersRead cap.)';
              }).join(' • '),
              _readingStats!.favoriteBooks.map((book) {
                final chaptersRead = _readingStats!.bookProgress[book] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeManager.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeManager.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        book,
                        style: TextStyle(
                          color: themeManager.primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$chaptersRead capítulos',
                        style: TextStyle(
                          color: themeManager.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          if (_readingStats!.favoriteBooks.isNotEmpty)
            const SizedBox(height: 16),

          // Leituras recentes (expansível)
          if (_recentReadings.isNotEmpty)
            _buildExpandableCard(
              themeManager,
              'Leituras Recentes (7 dias)',
              Icons.history,
              '${_recentReadings.length} leituras nos últimos 7 dias',
              _recentReadings.map((reading) {
                final daysDiff = DateTime.now().difference(reading.readDate).inDays;
                String dateText;
                
                if (daysDiff == 0) {
                  dateText = 'Hoje';
                } else if (daysDiff == 1) {
                  dateText = 'Ontem';
                } else {
                  dateText = '$daysDiff dias atrás';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeManager.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeManager.primaryColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: themeManager.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.menu_book,
                          color: themeManager.primaryColor,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${reading.bookName} ${reading.chapter}',
                              style: TextStyle(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${reading.bibleVersion} • $dateText',
                              style: TextStyle(
                                color: themeManager.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeManager.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${reading.pointsEarned}',
                          style: TextStyle(
                            color: themeManager.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
