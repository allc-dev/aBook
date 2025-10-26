import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/game_session_model.dart';
import '../models/question_model.dart';
import '../services/game_session_service.dart';
import '../services/verse_quiz_service.dart';
import '../database/database_helper.dart';
import '../database/bible_database_manager.dart';

enum GameState {
  loading,
  canPlay,
  selectingDifficulty,
  playing,
  inGame,
  questionAnswered,
  sessionComplete,
  sessionEnded,
  gameOver,
  paused,
  error,
}

class GameProvider extends ChangeNotifier {
  /// Atualiza as estatísticas do jogador e notifica listeners
  Future<void> reloadStats({bool force = false}) async {
    await _updateStatsCache(force: force);
  }
  final GameSessionService _sessionService = GameSessionService();
  
  // Estado do jogo
  GameState _gameState = GameState.loading;
  String? _errorMessage;
  
  // Dados do jogador
  String? _playerName;
  int _playerLevel = 1;
  int _totalExperience = 0;
  
  // Sessão e perguntas
  GameSessionModel? get currentSession => _sessionService.currentSession;
  QuestionModel? get currentQuestion => _sessionService.currentQuestion;
  List<String> _shuffledAlternatives = [];
  
  // UI State
  String? _selectedAnswer;
  int? _selectedAlternativeIndex;
  bool _isSubmittingAnswer = false;
  bool _lastAnswerCorrect = false;
  Timer? _questionTimer;
  int _timeRemaining = 60;
  String? _defaultDifficulty;
  
  // Getters públicos
  GameState get gameState => _gameState;
  String? get errorMessage => _errorMessage;
  GameSessionService get sessionService => _sessionService;
  bool get hasMoreQuestions => _sessionService.hasMoreQuestions;
  String? get playerName => _playerName;
  int get playerLevel => _playerLevel;
  int get totalExperience => _totalExperience;
  String get playerTitle => _getPlayerTitle();
  List<String> get shuffledAlternatives => List.unmodifiable(_shuffledAlternatives);
  String? get selectedAnswer => _selectedAnswer;
  int? get selectedAlternativeIndex => _selectedAlternativeIndex;
  bool get isSubmittingAnswer => _isSubmittingAnswer;
  bool get lastAnswerCorrect => _lastAnswerCorrect;
  int get timeRemaining => _timeRemaining;
  int get remainingLives => _sessionService.remainingLives;
  bool get hasAnswered => currentQuestion?.isAnswered ?? false;
  String? get defaultDifficulty => _defaultDifficulty;
  
  // Getters adicionais para a UI
  int get currentQuestionIndex => _sessionService.currentQuestionIndex;
  int get questionsPerSession => 10;
  int get score => currentSession?.totalPoints ?? 0;
  int get currentStreak => currentSession?.currentStreak ?? 0;
  int get lives => remainingLives;

  /// Estatísticas de leitura da Bíblia para HomeScreen
  int get chaptersRead {
    // Tenta buscar do cache de estatísticas, se disponível
    if (_cachedStats != null && _cachedStats!.containsKey('reading_total_chapters')) {
      return _cachedStats!['reading_total_chapters'] as int? ?? 0;
    }
    // Alternativamente, pode buscar de outro serviço/modelo se necessário
    return 0;
  }

  int get readingDays {
    if (_cachedStats != null && _cachedStats!.containsKey('reading_total_days')) {
      return _cachedStats!['reading_total_days'] as int? ?? 0;
    }
    return 0;
  }
  
  // Estatísticas da sessão atual
  int get questionsAnswered => currentSession?.totalQuestions ?? 0;
  int get correctAnswers => currentSession?.correctAnswers ?? 0;
  double get accuracy => currentSession?.accuracy ?? 0.0;

  GameProvider() {
    _initialize();
  }

  /// Inicializa o provider
  Future<void> _initialize() async {
    _gameState = GameState.loading;
    notifyListeners();
    
    try {
      print('🚀 Inicializando GameProvider...');
      
      // Inicializar sistema de bancos com prioridade
      print('🔧 Verificando inicialização do sistema de bancos...');
      await _ensureDatabaseSystemInitialized();
      print('✅ Sistema de bancos verificado');
      
      // Carregar dados do jogador (com tratamento de erro)
      await _loadPlayerData();
      print('✅ Dados do jogador carregados');
      
      // Carregar estatísticas do banco de dados
      await _updateStatsCache();
      print('✅ Cache de estatísticas carregado');
      
      // Sempre permitir acesso à tela inicial
      _gameState = GameState.canPlay;
      print('✅ GameProvider inicializado com sucesso');
    } catch (e) {
      print('❌ Erro na inicialização do GameProvider: $e');
      _setError('Erro ao inicializar: $e');
    }
    
    notifyListeners();
  }

  /// Garante que o sistema de bancos está inicializado
  Future<void> _ensureDatabaseSystemInitialized() async {
    try {
      // Verificar se já foi inicializado checando se consegue acessar o banco
      final dbHelper = DatabaseHelper();
      await dbHelper.initialize();
      print('✅ Sistema de bancos inicializado');
    } catch (e) {
      print('❌ Erro na inicialização do sistema de bancos: $e');
      rethrow;
    }
  }

  /// Inicia uma nova sessão com a dificuldade escolhida
  Future<void> startNewSession(String difficulty) async {
    try {
      // Verificar se pode jogar hoje
      final canPlay = await _sessionService.canPlayToday();
      if (!canPlay) {
        _setError('Você já jogou hoje! Volte amanhã para uma nova sessão.');
        return;
      }
      
      // Verificar se há dados para gerar perguntas, se não, popular dados de teste
      print('🔍 Verificando se há dados para quiz antes de começar...');
      await _ensureQuizDataExists();
      print('✅ Verificação de dados concluída');
      
      final success = await _sessionService.startNewSession(difficulty);

      if (success) {
        await VerseQuizService().incrementSessionCount();
        _gameState = GameState.inGame;
        _setupCurrentQuestion();
        _startQuestionTimer();
      } else {
        _setError('Não foi possível iniciar o jogo');
      }
    } catch (e) {
      _setError('Erro ao iniciar sessão: $e');
    }

    notifyListeners();
  }

  /// Limpa dados corrompidos (chapter ou verse = 0)
  Future<void> _cleanCorruptedVerseData(Database gameDb) async {
    print('🧹 Limpando dados corrompidos...');
    try {
      // Contar dados corrompidos antes da limpeza
      final corruptedCount = Sqflite.firstIntValue(
        await gameDb.rawQuery('''
          SELECT COUNT(*) FROM verse_quiz_data 
          WHERE chapter = 0 OR verse = 0 OR chapter IS NULL OR verse IS NULL
        ''')
      ) ?? 0;
      
      if (corruptedCount > 0) {
        print('⚠️ Encontrados $corruptedCount registros corrompidos. Removendo...');
        
        // Remover dados corrompidos
        await gameDb.rawDelete('''
          DELETE FROM verse_quiz_data 
          WHERE chapter = 0 OR verse = 0 OR chapter IS NULL OR verse IS NULL
        ''');
        
        print('✅ Dados corrompidos removidos com sucesso!');
      } else {
        print('✅ Nenhum dado corrompido encontrado.');
      }
    } catch (e) {
      print('❌ Erro ao limpar dados corrompidos: $e');
    }
  }

  /// Garante que existem dados para o quiz
  Future<void> _ensureQuizDataExists() async {
    print('🔍 Entrando em _ensureQuizDataExists()');
    try {
      // Verificar se há versículos no banco de gamificação
      print('🔍 Tentando acessar banco de gamificação...');
      final gameDb = await DatabaseHelper().gameManager.database;
      print('✅ Banco de gamificação acessado com sucesso');
      
      // Primeiro, limpar dados corrompidos
      await _cleanCorruptedVerseData(gameDb);
      
      final count = Sqflite.firstIntValue(
        await gameDb.rawQuery('SELECT COUNT(*) FROM verse_quiz_data')
      ) ?? 0;
      
      print('📊 Verificando dados de quiz: $count registros encontrados');
      
      if (count == 0) {
        print('🔧 Populando dados de versículos das Bíblias...');
        
        // Primeiro tentar popular com dados reais das Bíblias
        await _populateVerseDataFromBibles(gameDb);
        
        // Verificar se funcionou
        final newCount = Sqflite.firstIntValue(
          await gameDb.rawQuery('SELECT COUNT(*) FROM verse_quiz_data')
        ) ?? 0;
        
        print('📊 Após população das Bíblias: $newCount registros');
        
        if (newCount == 0) {
        } else {
          print('✅ $newCount versículos populados das Bíblias');
        }
      } else {
        print('✅ Dados já existem: $count registros');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao verificar dados do quiz: $e');
      print('📍 StackTrace: $stackTrace');
    }
  }
  
  /// Popula dados de versículos a partir das Bíblias instaladas
  Future<void> _populateVerseDataFromBibles(Database gameDb) async {
    try {
      // Usar NVI como referência para obter versículos
      final bibleManager = BibleDatabaseManager();
      final nviDb = await bibleManager.openBibleVersion('NVI');
      
      // Buscar versículos elegíveis (tamanho entre 50 e 300 caracteres)
      final verses = await nviDb.rawQuery('''
        SELECT v.id, v.chapter, v.verse, b.name as book_name, LENGTH(v.text) as char_count
        FROM verse v
        JOIN book b ON v.book_id = b.id
        WHERE LENGTH(v.text) BETWEEN 50 AND 300
        ORDER BY v.id
        LIMIT 2000
      ''');
      
      print('📊 Encontrados ${verses.length} versículos elegíveis para o quiz');
      
      if (verses.isNotEmpty) {
        Batch batch = gameDb.batch();
        int batchCount = 0;
        
        for (var verse in verses) {
          final charCount = verse['char_count'] as int;
          final wordCount = (charCount / 5).round(); // Estimativa
          
          batch.insert('verse_quiz_data', {
            'verse_id': verse['id'],
            'book_name': verse['book_name'],
            'chapter': verse['chapter'],
            'verse_number': verse['verse'],
            'is_quiz_eligible': 1,
            'word_count': wordCount,
            'character_count': charCount,
            'usage_count': 0,
          });
          
          batchCount++;
          
          // Executar em lotes para não sobrecarregar
          if (batchCount >= 100) {
            await batch.commit(noResult: true);
            batch = gameDb.batch();
            batchCount = 0;
          }
        }
        
        // Executar batch restante
        if (batchCount > 0) {
          await batch.commit(noResult: true);
        }
      }
      
    } catch (e) {
      print('❌ Erro ao popular dados das Bíblias: $e');
    }
  }

  /// Configura a pergunta atual
  void _setupCurrentQuestion() {
    if (currentQuestion != null) {
      _shuffledAlternatives = _getShuffledAlternatives(currentQuestion!);
      _selectedAnswer = null;
      _selectedAlternativeIndex = null;
  _timeRemaining = _initialTimeForDifficulty();
    } else {
      print('⚠️ Tentativa de configurar pergunta nula');
    }
  }

  /// Embaralha as alternativas incluindo a resposta correta
  List<String> _getShuffledAlternatives(QuestionModel question) {
    final allOptions = [question.correctAnswer, ...question.alternatives];
    allOptions.shuffle();
    return allOptions;
  }

  /// Inicia o timer da pergunta
  void _startQuestionTimer() {
    _questionTimer?.cancel();
  _timeRemaining = _initialTimeForDifficulty();
    
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        notifyListeners();
      } else {
        // Tempo esgotado - considerar resposta incorreta
        timer.cancel();
        _handleTimeOut();
      }
    });
  }

  /// Lida com o tempo esgotado
  void _handleTimeOut() {
    if (!hasAnswered && currentQuestion != null) {
      // Submeter resposta vazia (incorreta)
      _submitAnswer('');
    }
  }

  /// Seleciona uma alternativa
  void selectAnswer(String answer) {
    if (_gameState != GameState.inGame || hasAnswered || _isSubmittingAnswer) {
      return;
    }
    
    _selectedAnswer = answer;
    notifyListeners();
  }

  /// Confirma a resposta selecionada
  Future<void> confirmAnswer() async {
    if (_selectedAnswer == null || _isSubmittingAnswer) {
      return;
    }
    
    await _submitAnswer(_selectedAnswer!);
  }

  /// Submete a resposta
  Future<void> _submitAnswer(String answer) async {
    if (_isSubmittingAnswer || hasAnswered) {
      print('⚠️ Tentativa de submeter resposta ignorada - isSubmitting: $_isSubmittingAnswer, hasAnswered: $hasAnswered');
      return;
    }
    
    _isSubmittingAnswer = true;
    _questionTimer?.cancel();
    notifyListeners();
    
    try {
  final timeSpent = _initialTimeForDifficulty() - _timeRemaining;
      print('📝 Submetendo resposta: "$answer", tempo gasto: ${timeSpent}s');
      
      final gameCanContinue = await _sessionService.submitAnswer(answer, timeSpent: timeSpent);
      
      // Verificar se a resposta está correta
      _lastAnswerCorrect = (answer == currentQuestion?.correctAnswer);
      _gameState = GameState.questionAnswered;
      
      print('✅ Resposta processada - correta: $_lastAnswerCorrect, pode continuar: $gameCanContinue');
      
      // Se o jogo não pode continuar (3 erros atingidos), finalizar automaticamente
      if (!gameCanContinue) {
        print('🏁 Jogo terminou automaticamente - chamando _endSession()');
        _endSession();
        return;
      }
      
    } catch (e) {
      print('❌ Erro ao submeter resposta: $e');
      _setError('Erro ao submeter resposta: $e');
      // Em caso de erro, resetar estado para permitir nova tentativa
      _isSubmittingAnswer = false;
      return;
    }
    
    _isSubmittingAnswer = false;
    notifyListeners();
  }

  /// Avança para a próxima pergunta
  Future<void> nextQuestion() async {
    if (_gameState != GameState.questionAnswered) {
      return;
    }
    
    final hasMore = _sessionService.moveToNextQuestion();
    
    if (hasMore) {
      _gameState = GameState.inGame;
      _setupCurrentQuestion();
      _startQuestionTimer();
    } else {
      // Sessão completa
      await _sessionService.endSession();
      _gameState = GameState.sessionComplete;
    }
    
    notifyListeners();
  }

  /// Finaliza a sessão atual
  Future<void> endSession() async {
    _questionTimer?.cancel();
    await _sessionService.endSession();
    _gameState = GameState.sessionComplete;
    notifyListeners();
  }

  /// Abandona a sessão atual
  Future<void> abandonSession() async {
    _questionTimer?.cancel();
    await _sessionService.abandonSession();
    _gameState = GameState.canPlay;
    _clearSessionData();
    notifyListeners();
  }

  /// Volta ao menu principal
  void backToMenu() {
    _questionTimer?.cancel();
    _gameState = GameState.canPlay;
    _clearSessionData();
    notifyListeners();
  }

  /// Reinicia o jogo (volta para seleção de dificuldade)
  Future<void> restartGame() async {
    _questionTimer?.cancel();
    _clearSessionData();
    await _initialize();
  }

  /// Limpa dados da sessão
  void _clearSessionData() {
    _sessionService.clearSession();
    _shuffledAlternatives = [];
    _selectedAnswer = null;
    _selectedAlternativeIndex = null;
    _timeRemaining = _initialTimeForDifficulty();
    _errorMessage = null;
    _isSubmittingAnswer = false;
    _lastAnswerCorrect = false;
  }

  /// Define um erro
  void _setError(String message) {
    _errorMessage = message;
    _gameState = GameState.error;
    print('❌ GameProvider Error: $message');
  }

  /// Limpa o erro atual
  void clearError() {
    _errorMessage = null;
    if (_gameState == GameState.error) {
      _gameState = GameState.canPlay;
    }
    notifyListeners();
  }

  /// Obtém tempo até a próxima sessão
  Future<String?> getTimeUntilNextSession() async {
    final duration = await _sessionService.getTimeUntilNextSession();
    if (duration == null) return null;
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  /// Obtém resumo da sessão atual
  Map<String, dynamic> getSessionSummary() {
    return _sessionService.getSessionSummary();
  }

  /// Obtém cor da resposta (para feedback visual)
  Color? getAnswerColor(String answer) {
    if (!hasAnswered || currentQuestion == null) {
      return null;
    }
    
    if (answer == currentQuestion!.correctAnswer) {
      return const Color(0xFF4CAF50); // Verde para correto
    } else if (answer == _selectedAnswer) {
      return const Color(0xFFF44336); // Vermelho para seleção incorreta
    }
    
    return null;
  }

  /// Verifica se uma resposta específica é a correta
  bool isCorrectAnswer(String answer) {
    return currentQuestion?.correctAnswer == answer;
  }

  /// Verifica se uma resposta específica foi selecionada
  bool isSelectedAnswer(String answer) {
    return _selectedAnswer == answer;
  }

  // Métodos adicionais para controle do jogo
  
  /// Pausa o jogo
  void pauseGame() {
    if (_gameState == GameState.playing) {
      _gameState = GameState.paused;
      _questionTimer?.cancel();
      notifyListeners();
    }
  }

  /// Retoma o jogo pausado
  void resumeGame() {
    if (_gameState == GameState.paused) {
      _gameState = GameState.playing;
      _startQuestionTimer();
      notifyListeners();
    }
  }

  /// Decrementa o timer da pergunta
  void decrementTimer() {
    if (_timeRemaining > 0) {
      _timeRemaining--;
      notifyListeners();
      
      if (_timeRemaining == 0) {
        // Tempo esgotado, submeter como resposta incorreta
        _handleTimeUp();
      }
    }
  }

  /// Seleciona uma alternativa pelo índice
  void selectAlternative(int index) {
    if (!(_gameState == GameState.playing || _gameState == GameState.inGame) || hasAnswered) return;
    _selectedAlternativeIndex = index;
    if (index < _shuffledAlternatives.length) {
      _selectedAnswer = _shuffledAlternatives[index];
    }
    notifyListeners();
  }



  /// Avança para a próxima pergunta
  void goToNextQuestion() {
    if (_gameState == GameState.questionAnswered) {
      // Verificar se o jogo acabou por falta de vidas ANTES de tentar avançar
      if (remainingLives <= 0) {
        print('🏁 Game Over - sem vidas restantes');
        _endSession();
        return;
      }
      
      // Tentar avançar para próxima pergunta
      final hasMore = _sessionService.moveToNextQuestion();
      
      if (!hasMore) {
        // Fim das perguntas - encerrar sessão diretamente
        print('🏁 Fim das perguntas');
        _endSession();
        return;
      }
      
      // Preparar próxima pergunta
      _prepareNextQuestion();
    }
  }

  /// Trata quando o tempo da pergunta esgota
  void _handleTimeUp() async {
    _selectedAnswer = ''; // Resposta vazia indica tempo esgotado
    _selectedAlternativeIndex = null;
    _lastAnswerCorrect = false;
    
    try {
  await _sessionService.submitAnswer('', timeSpent: _initialTimeForDifficulty() - _timeRemaining);
      _gameState = GameState.questionAnswered;
      notifyListeners();
    } catch (e) {
      _setError('Erro ao processar resposta: ${e.toString()}');
    }
  }

  /// Prepara a próxima pergunta
  void _prepareNextQuestion() {
    print('🔄 Preparando próxima pergunta...');
    
    _questionTimer?.cancel();
    _selectedAnswer = null;
    _selectedAlternativeIndex = null;
    _lastAnswerCorrect = false;
    _isSubmittingAnswer = false;
  _timeRemaining = _initialTimeForDifficulty();

    // Configurar próxima pergunta
    _gameState = GameState.inGame;
    _setupCurrentQuestion();
    _startQuestionTimer();
    
    print('✅ Próxima pergunta preparada - Pergunta ${currentQuestionIndex + 1}');
    notifyListeners();
  }

  /// Encerra a sessão atual
  void _endSession() {
    print('🔚 _endSession() chamado no provider');
    print('📊 Dados ANTES do endSession do service:');
    print('   - currentSession no provider: ${currentSession?.totalPoints}');
    print('   - sessionService.currentSession: ${_sessionService.currentSession?.totalPoints}');
    
    // Adicionar XP baseado nos pontos da sessão
    final sessionPoints = currentSession?.totalPoints ?? 0;
    if (sessionPoints > 0) {
      addExperience(sessionPoints);
      print('✨ Adicionado ${sessionPoints} XP ao jogador');
    }
    
    _gameState = GameState.sessionEnded;
    _questionTimer?.cancel();
    _sessionService.endSession();
    
    print('📊 Dados DEPOIS do endSession do service:');
    print('   - currentSession no provider: ${currentSession?.totalPoints}');
    print('   - sessionService.currentSession: ${_sessionService.currentSession?.totalPoints}');
    
    // Atualizar cache de estatísticas após finalizar a sessão
    _updateStatsCache();
    
    notifyListeners();
  }
  
  /// Finaliza o jogo (após mostrar a última resposta)
  void finishGame() {
    print('🏁 finishGame() chamado');
    print('📊 Dados ANTES de finalizar:');
    print('   - Pontos: ${currentSession?.totalPoints}');
    print('   - Corretas: ${currentSession?.correctAnswers}/${currentSession?.totalQuestions}');
    _endSession();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  // Métodos do sistema de jogador
  
  /// Define o nome do jogador
  Future<void> setPlayerName(String name) async {
    _playerName = name;
    await _savePlayerData();
    notifyListeners();
  }

  /// Carrega dados do jogador salvos
  Future<void> _loadPlayerData() async {
    try {
      print('📱 Carregando dados do jogador...');
      final prefs = await SharedPreferences.getInstance();
      
      _playerName = prefs.getString('player_name');
      _playerLevel = prefs.getInt('player_level') ?? 1;
  _totalExperience = prefs.getInt('total_experience') ?? 0;
  _defaultDifficulty = prefs.getString('default_difficulty');
      
      print('📱 Dados do jogador carregados: $_playerName, Level: $_playerLevel, XP: $_totalExperience');
    } catch (e) {
      print('❌ Erro ao carregar dados do jogador: $e');
      // Valores padrão em caso de erro
      _playerName = null;
      _playerLevel = 1;
      _totalExperience = 0;
      // Não relançar o erro - usar valores padrão
    }
  }

  /// Salva dados do jogador
  Future<void> _savePlayerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_playerName != null) {
        await prefs.setString('player_name', _playerName!);
      }
      await prefs.setInt('player_level', _playerLevel);
      await prefs.setInt('total_experience', _totalExperience);
      if (_defaultDifficulty != null) {
        await prefs.setString('default_difficulty', _defaultDifficulty!);
      }
      
      print('💾 Dados do jogador salvos: $_playerName, Level: $_playerLevel, XP: $_totalExperience');
    } catch (e) {
      print('❌ Erro ao salvar dados do jogador: $e');
    }
  }

  // Dificuldade padrão
  Future<void> setDefaultDifficulty(String? difficulty) async {
    _defaultDifficulty = difficulty;
    await _savePlayerData();
    notifyListeners();
  }

  // Preferências de Dificuldade
  int _initialTimeForDifficulty() {
    final diff = _sessionService.currentSession?.difficultyLevel.toLowerCase();
    switch (diff) {
      case 'fácil':
        return 120;
      case 'médio':
        return 90;
      case 'difícil':
        return 60;
      default:
        return 60;
    }
  }

  /// Adiciona experiência e verifica level up
  void addExperience(int xp) {
    _totalExperience += xp;
    
    final newLevel = _calculateLevel(_totalExperience);
    if (newLevel > _playerLevel) {
      _playerLevel = newLevel;
      print('🎉 Level Up! Nível ${_playerLevel} alcançado!');
      // TODO: Mostrar notificação de level up
    }
    
    _savePlayerData(); // Remover await aqui
    notifyListeners();
  }

  /// Calcula o nível baseado na experiência total
  int _calculateLevel(int experience) {
    // Sistema progressivo: 100 XP base + 20% por nível
    // Nível 1: 0 XP
    // Nível 2: 100 XP
    // Nível 3: 100 + 120 = 220 XP
    // Nível 4: 220 + 144 = 364 XP
    // E assim por diante...
    
    if (experience < 100) return 1;
    
    int level = 2;
    int totalXpRequired = 100;
    int currentLevelXp = 100; 
    
    while (experience >= totalXpRequired) {
      level++;
      currentLevelXp = (currentLevelXp * 1.2).round();
      totalXpRequired += currentLevelXp;
    }
    
    return level - 1;
  }

  /// Retorna XP necessário para o próximo nível
  int get experienceToNextLevel {
    final nextLevelXP = _getXPForLevel(_playerLevel + 1);
    return nextLevelXP - _totalExperience;
  }

  /// Retorna XP total necessário para um nível específico
  int _getXPForLevel(int level) {
    if (level <= 1) return 0;
    
    // Sistema progressivo: 100 base + 20% por nível
    int totalXP = 0;
    int levelXP = 100; // XP base para nível 2
    
    for (int i = 2; i <= level; i++) {
      totalXP += levelXP;
      levelXP = (levelXP * 1.2).round(); // Aumenta 20%
    }
    
    return totalXP;
  }

  /// Retorna progresso atual do nível (0.0 a 1.0)
  double get levelProgress {
    final currentLevelXP = _getXPForLevel(_playerLevel);
    final nextLevelXP = _getXPForLevel(_playerLevel + 1);
    
    if (nextLevelXP == currentLevelXP) return 0.0;
    
    final xpInCurrentLevel = _totalExperience - currentLevelXP;
    final xpNeededForLevel = nextLevelXP - currentLevelXP;
    
    final progress = (xpInCurrentLevel / xpNeededForLevel).clamp(0.0, 1.0);
    print('📊 Progresso XP: ${_totalExperience}/${nextLevelXP} = ${progress}');
    return progress;
  }

  /// Retorna título do jogador baseado no nível
  String _getPlayerTitle() {
    if (_playerLevel < 5) return 'Iniciante';
    if (_playerLevel < 10) return 'Estudioso';
    if (_playerLevel < 15) return 'Conhecedor';
    if (_playerLevel < 20) return 'Sábio';
    if (_playerLevel < 25) return 'Mestre';
    if (_playerLevel < 30) return 'Erudito';
    return 'Doutor da Palavra';
  }

  /// Verifica se tem nome de jogador definido
  bool get hasPlayerName => _playerName != null && _playerName!.isNotEmpty;
  
  // Estatísticas em cache para evitar múltiplas consultas
  Map<String, dynamic>? _cachedStats;
  DateTime? _lastStatsUpdate;

  /// Precisão geral do jogador (busca dados reais do banco de gamificação)
  double get overallAccuracy {
    if (_cachedStats != null) {
      final totalQuestions = _cachedStats!['total_questions'] ?? _cachedStats!['total_questions_answered'] ?? 0;
      final totalCorrect = _cachedStats!['total_correct'] ?? _cachedStats!['total_correct_answers'] ?? 0;
      if (totalQuestions == 0) return 0.0;
      return (totalCorrect / totalQuestions) * 100;
    }
    return 0.0;
  }

  /// Dias jogados (busca dados reais do banco de gamificação)
  int get daysPlayed {
    if (_cachedStats != null) {
      return _cachedStats!['days_played'] ?? 0;
    }
    return 0;
  }

  /// Total de pontos do banco de gamificação
  int get totalPointsFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['total_points'] ?? 0;
    }
    return 0;
  }

  /// Total de sessões
  int get totalSessionsFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['total_sessions'] ?? 0;
    }
    return 0;
  }

  /// Total de perguntas respondidas
  int get totalQuestionsAnsweredFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['total_questions_answered'] ?? _cachedStats!['total_questions'] ?? 0;
    }
    return 0;
  }

  /// Total de respostas corretas
  int get totalCorrectAnswersFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['total_correct_answers'] ?? _cachedStats!['total_correct'] ?? 0;
    }
    return 0;
  }

  /// Melhor sequência
  int get bestStreakFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['best_streak'] ?? 0;
    }
    return 0;
  }

  /// Sequência atual
  int get currentStreakFromDB {
    if (_cachedStats != null) {
      return _cachedStats!['current_streak'] ?? 0;
    }
    return 0;
  }

  /// Atualiza o cache de estatísticas do banco de gamificação
  Future<void> _updateStatsCache({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (force || _cachedStats == null || _lastStatsUpdate == null || now.difference(_lastStatsUpdate!).inMinutes >= 1) {
        print('🔄 Atualizando cache de estatísticas do banco de gamificação...');
        final userStats = await VerseQuizService().getUserStats();
        final progress = userStats['progress'];
        if (progress is Map) {
          _cachedStats = Map<String, dynamic>.from(progress);
        } else {
          _cachedStats = {};
        }
        _lastStatsUpdate = now;
        print('📊 Stats carregadas: $_cachedStats');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Erro ao atualizar cache de estatísticas: $e');
    }
  }
  
  /// Verifica se pode jogar hoje
  Future<bool> canPlayToday() async {
    return await _sessionService.canPlayToday();
  }
}
