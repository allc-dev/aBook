import 'dart:async';
import '../models/game_session_model.dart';
import '../models/question_model.dart';
import '../database/bible_repository.dart';
import 'question_generator.dart';

class GameSessionService {
  final BibleRepository _repository = BibleRepository();
  final QuestionGeneratorService _questionGenerator = QuestionGeneratorService();
  
  GameSessionModel? _currentSession;
  List<QuestionModel> _sessionQuestions = [];
  int _currentQuestionIndex = 0;
  
  // Getters para acessar o estado atual
  GameSessionModel? get currentSession => _currentSession;
  List<QuestionModel> get sessionQuestions => List.unmodifiable(_sessionQuestions);
  int get currentQuestionIndex => _currentQuestionIndex;
  QuestionModel? get currentQuestion => 
      _currentQuestionIndex < _sessionQuestions.length 
          ? _sessionQuestions[_currentQuestionIndex] 
          : null;
  bool get hasMoreQuestions => _currentQuestionIndex < _sessionQuestions.length - 1;
  int get remainingLives {
    final max = _currentSession?.maxErrors ?? 3;
    final wrong = _currentSession?.wrongAnswers ?? 0;
    return max - wrong;
  }

  /// Verifica se o usuário pode jogar hoje
  Future<bool> canPlayToday() async {
    try {
      return !(await _repository.hasPlayedToday());
    } catch (e) {
      print('❌ Erro ao verificar sessão diária: $e');
      return false;
    }
  }

  /// Inicia uma nova sessão de jogo
  Future<bool> startNewSession(String difficulty) async {
    try {
      // Verificar se há uma sessão ativa
      if (_currentSession != null && !_currentSession!.isCompleted) {
        print('⚠️ Já existe uma sessão ativa');
        return false;
      }

      // Criar nova sessão
      _currentSession = GameSessionModel(difficultyLevel: difficulty);
      // Configurar vidas (maxErrors) por dificuldade
      switch (difficulty.toLowerCase()) {
        case 'fácil':
          _currentSession!.maxErrors = 1000000;
          break;
        case 'médio':
          _currentSession!.maxErrors = 5;
          break;
        default:
          _currentSession!.maxErrors = 3;
      }
      
      // Gerar perguntas para a sessão
      print('🔄 Gerando perguntas para dificuldade: $difficulty');
      _sessionQuestions = await _questionGenerator.generateQuestions(difficulty, count: 10);
      
      if (_sessionQuestions.isEmpty) {
        print('❌ Não foi possível gerar perguntas');
        _currentSession = null;
        return false;
      }

      _currentQuestionIndex = 0;
      
      // Salvar sessão no banco
      await _repository.saveGameSession(_currentSession!);
      
      print('✅ Nova sessão iniciada: ${_currentSession!.id}');
      print('📝 ${_sessionQuestions.length} perguntas geradas');
      
      return true;
    } catch (e) {
      print('❌ Erro ao iniciar sessão: $e');
      _currentSession = null;
      _sessionQuestions.clear();
      return false;
    }
  }

  /// Retoma uma sessão existente
  Future<bool> resumeSession() async {
    try {
      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) {
        return false;
      }

      _currentSession = activeSession;
      
      // Recarregar perguntas da sessão (simplificado)
      // Em uma implementação completa, as perguntas da sessão seriam salvas
      _sessionQuestions = await _questionGenerator.generateQuestions(
        _currentSession!.difficultyLevel, 
        count: 10
      );
      
      _currentQuestionIndex = _currentSession!.totalQuestions;
      
      print('🔄 Sessão retomada: ${_currentSession!.id}');
      return true;
    } catch (e) {
      print('❌ Erro ao retomar sessão: $e');
      return false;
    }
  }

  /// Submete uma resposta para a pergunta atual
  Future<bool> submitAnswer(String selectedAnswer, {int? timeSpent}) async {
    if (_currentSession == null || currentQuestion == null) {
      print('❌ Nenhuma sessão ativa ou pergunta atual');
      return false;
    }

    try {
      final question = currentQuestion!;
      final timeToAnswer = timeSpent ?? 30;
      
      // Processar resposta
      question.submitAnswer(selectedAnswer, timeToAnswer);
      
      // Atualizar estatísticas da sessão
      if (question.wasCorrect) {
        _currentSession!.addCorrectAnswer(question.pointsEarned);
        print('✅ Resposta correta! +${question.pointsEarned} pontos');
      } else {
        _currentSession!.addWrongAnswer();
        print('❌ Resposta incorreta. Vidas restantes: ${remainingLives}');
      }

      // Salvar resposta no banco usando o novo sistema
      await _repository.saveUserResponse(
        verseId: question.verse.id,
        sessionId: _currentSession!.id,
        isCorrect: question.wasCorrect,
        difficultyChosen: _currentSession!.difficultyLevel,
        alternatives: question.alternatives,
        timeToAnswer: timeToAnswer,
        pointsEarned: question.pointsEarned,
        bookName: question.verse.bookName, 
        streakAtTime: _currentSession!.currentStreak, 
      );

      // Atualizar sessão no banco
      await _repository.updateGameSession(_currentSession!);

      // Verificar se o jogo acabou (mas não finalizar ainda)
      if (_currentSession!.isGameOver) {
        print('🏁 Game Over detectado - 3 erros atingidos');
        return false;
      }

      print('📊 Sessão: ${_currentSession!.correctAnswers}/${_currentSession!.totalQuestions} corretas, ${_currentSession!.totalPoints} pontos');
      return true;
    } catch (e) {
      print('❌ Erro ao submeter resposta: $e');
      return false;
    }
  }

  /// Avança para a próxima pergunta
  bool moveToNextQuestion() {
    // Se o jogo acabou (3 erros), não avançar
    if (_currentSession != null && _currentSession!.isGameOver) {
      print('🚫 Game Over - não avançando pergunta');
      return false;
    }
    
    if (hasMoreQuestions) {
      _currentQuestionIndex++;
      print('➡️ Avançando para pergunta ${_currentQuestionIndex + 1}/${_sessionQuestions.length}');
      return true;
    }
    return false;
  }

  /// Finaliza a sessão atual
  Future<void> endSession() async {
    await _endSession();
  }

  Future<void> _endSession() async {
    if (_currentSession == null) return;

    try {
      print('🔚 Finalizando sessão no service');
      print('📊 Dados antes de finalizar:');
      print('   - Pontos: ${_currentSession!.totalPoints}');
      print('   - Corretas: ${_currentSession!.correctAnswers}/${_currentSession!.totalQuestions}');
      print('   - Status: ${_currentSession!.status}');
      
      _currentSession!.endSession();
      
      // Salvar sessão finalizada
      await _repository.updateGameSession(_currentSession!);
      
      // Atualizar estatísticas diárias
      await _repository.updateDailyStats(_currentSession!);
      
      // Verificar conquistas
      await _checkAchievements();
      
      print('🏁 Sessão finalizada: ${_currentSession!.totalPoints} pontos em ${_currentSession!.formattedDuration}');
      
      // NÃO limpar a sessão aqui - manter os dados para a tela de resultados
      // _currentSession = null;
      
    } catch (e) {
      print('❌ Erro ao finalizar sessão: $e');
    }
  }

  /// Abandona a sessão atual
  Future<void> abandonSession() async {
    if (_currentSession == null) return;

    try {
      _currentSession!.abandonSession();
      await _repository.updateGameSession(_currentSession!);
      
      _currentSession = null;
      _sessionQuestions.clear();
      _currentQuestionIndex = 0;
      
      print('🚪 Sessão abandonada');
    } catch (e) {
      print('❌ Erro ao abandonar sessão: $e');
    }
  }

  /// Verifica e desbloqueia conquistas
  Future<void> _checkAchievements() async {
    if (_currentSession == null) return;

    try {
      final stats = await _repository.getOverallStats();
      
      // Primeira sessão
      if (stats['days_played'] == 1) {
        await _repository.unlockAchievement('Primeiro Passo');
      }
      
      // Conquistas por número de acertos
      if (stats['total_correct'] >= 20) {
        await _repository.unlockAchievement('Conhecedor');
      }
      if (stats['total_correct'] >= 50) {
        await _repository.unlockAchievement('Especialista');
      }
      
      // Sessão perfeita
      if (_currentSession!.correctAnswers > 0 && _currentSession!.wrongAnswers == 0) {
        await _repository.unlockAchievement('Perfeccionista');
      }
      
    } catch (e) {
      print('❌ Erro ao verificar conquistas: $e');
    }
  }

  /// Limpa o estado da sessão atual (só chamar após mostrar resultados)
  void clearSession() {
    print('🧹 Limpando dados da sessão');
    _currentSession = null;
    _sessionQuestions.clear();
    _currentQuestionIndex = 0;
  }

  /// Obtém um resumo da sessão atual
  Map<String, dynamic> getSessionSummary() {
    if (_currentSession == null) {
      return {'active': false};
    }

    return {
      'active': true,
      'id': _currentSession!.id,
      'difficulty': _currentSession!.difficultyLevel,
      'totalQuestions': _currentSession!.totalQuestions,
      'correctAnswers': _currentSession!.correctAnswers,
      'wrongAnswers': _currentSession!.wrongAnswers,
      'totalPoints': _currentSession!.totalPoints,
      'currentStreak': _currentSession!.currentStreak,
      'bestStreak': _currentSession!.bestStreak,
      'remainingLives': remainingLives,
      'accuracy': _currentSession!.accuracy,
      'duration': _currentSession!.formattedDuration,
      'isGameOver': _currentSession!.isGameOver,
      'questionsRemaining': _sessionQuestions.length - _currentQuestionIndex - 1,
    };
  }

  /// Obtém tempo até a próxima sessão (se já jogou hoje)
  Future<Duration?> getTimeUntilNextSession() async {
    if (await canPlayToday()) {
      return null; // Pode jogar agora
    }

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}
