
import 'package:sqflite/sqflite.dart';
import '../models/verse_model.dart';
import '../models/game_session_model.dart';
import 'database_helper.dart';
import '../services/verse_quiz_service.dart';
import '../services/bible_settings_service.dart';
import 'game_database_manager.dart';

class BibleRepository {
  static final BibleRepository _instance = BibleRepository._internal();
  factory BibleRepository() => _instance;
  BibleRepository._internal();

  DatabaseHelper get _dbHelper => DatabaseHelper();
  VerseQuizService get _verseQuizService => VerseQuizService();
  BibleSettingsService get _settingsService => BibleSettingsService();

  // Buscar versículos elegíveis usando o novo sistema de versões múltiplas
  Future<List<VerseModel>> getEligibleVerses({required String difficulty, int count = 10}) async {
    try {
      // Buscar versículos usando o novo serviço que já considera a versão atual
      final versesData = await _verseQuizService.getQuizVerses(difficulty, limit: count);
      
      // Converter para VerseModel mantendo compatibilidade
      List<VerseModel> verses = [];
      for (var verseData in versesData) {
        verses.add(VerseModel(
          id: verseData['verse_id'],
          bookId: verseData['book_id'] ?? 0,
          chapter: verseData['chapter'] ?? 0,
          verse: verseData['verse_number'] ?? 0,
          text: verseData['text'],
          bookName: verseData['book_name'],
          difficultyLevel: difficulty,
          pointsValue: verseData['points_value'] ?? _getDefaultPointsForDifficulty(difficulty),
        ));
      }
      
      print('✅ BibleRepository: ${verses.length} versículos encontrados para $difficulty');
      return verses;
    } catch (e) {
      print('❌ Erro ao buscar versículos elegíveis: $e');
      return [];
    }
  }

  // Manter compatibilidade com métodos antigos (agora usando o novo sistema)
  Future<List<int>> getEligibleVerseIds({required String difficulty}) async {
    final verses = await getEligibleVerses(difficulty: difficulty, count: 50);
    return verses.map((v) => v.id).toList();
  }

  // Método auxiliar para pontos por dificuldade
  int _getDefaultPointsForDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'fácil':
        return 10;
      case 'médio':
        return 20;
      case 'difícil':
        return 30;
      default:
        return 15;
    }
  }

  /// Seleção balanceada por testamento (AT/NT) - agora via novo sistema
  Future<List<int>> getEligibleVerseIdsBalanced({required String difficulty, required int count}) async {
    // No novo sistema, o balanceamento já é feito pelo VerseQuizService
    return getEligibleVerseIds(difficulty: difficulty);
  }

  // Buscar versículos por IDs - agora via novo sistema
  Future<List<VerseModel>> getVersesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      // Buscar versão atual do usuário
      String currentVersion = await _settingsService.getCurrentBibleVersion();
      
      List<VerseModel> verses = [];
      for (int verseId in ids) {
        // Buscar versículo na versão atual
        final verseData = await DatabaseHelper().bibleManager.getVerse(currentVersion, verseId);
        
        if (verseData != null) {
          // Buscar informações complementares do banco de gamificação
          final gameDb = await DatabaseHelper().gameManager.database;
          
          final bookDiffData = await gameDb.query(
            'book_difficulty',
            where: 'book_name = ?',
            whereArgs: [verseData['book_name']],
            limit: 1,
          );
          
          verses.add(VerseModel(
            id: verseId,
            bookId: verseData['book_id'] ?? 0,
            chapter: verseData['chapter'] ?? 0,
            verse: verseData['verse_number'] ?? 0,
            text: verseData['text'],
            bookName: verseData['book_name'],
            difficultyLevel: bookDiffData.isNotEmpty ? bookDiffData.first['difficulty_level'] as String? : null,
            pointsValue: bookDiffData.isNotEmpty ? bookDiffData.first['points_value'] as int? : null,
          ));
        }
      }
      
      return verses;
    } catch (e) {
      print('❌ Erro ao buscar versículos por IDs: $e');
      return [];
    }
  }

  // 🎯 GERAR ALTERNATIVAS INTELIGENTES
  Future<List<String>> generateAlternatives(String correctAnswer, String testamentType) async {
    // Usar o banco de gamificação em vez do banco da Bíblia para buscar alternativas
    final gameDb = await GameDatabaseManager().database;
    
    // Determinar se o livro correto é do Antigo ou Novo Testamento
    final testament = getTestamentByBookName(correctAnswer);
    
    print('🎯 Gerando alternativas para "$correctAnswer" (testamento: $testament)');
    
    // Buscar TODOS os livros disponíveis que não sejam a resposta correta
    String query = '''
      SELECT DISTINCT vqd.book_name
      FROM verse_quiz_data vqd
      WHERE vqd.book_name != ?
      ORDER BY RANDOM()
      LIMIT 10
    ''';
    
    List<Map<String, dynamic>> result = await gameDb.rawQuery(query, [correctAnswer]);
    
    List<String> alternatives = result.map((row) => row['book_name'] as String).toList();
    
    // Se não tiver livros suficientes, usar livros fixos conhecidos
    if (alternatives.length < 3) {
      Set<String> allAlternatives = alternatives.toSet();
      
      // Adicionar livros comuns que não sejam a resposta correta
      List<String> commonBooks = [
        'Mateus', 'Marcos', 'Lucas', 'João', 'Atos',
        'Gênesis', 'Êxodo', 'Levítico', 'Números', 'Deuteronômio',
        'Salmos', 'Provérbios', 'Eclesiastes', 'Isaías', 'Jeremias'
      ];
      
      for (String book in commonBooks) {
        if (book != correctAnswer && allAlternatives.length < 3) {
          allAlternatives.add(book);
        }
      }
      
      alternatives = allAlternatives.toList();
    }
    
    // Garantir que temos pelo menos 3 alternativas, mesmo se precisar repetir
    while (alternatives.length < 3) {
      alternatives.add(alternatives.isNotEmpty ? alternatives.first : 'Mateus');
    }
    
    // Pegar apenas as primeiras 3 alternativas
    alternatives = alternatives.take(3).toList();
    
    print('🎯 Alternativas finais encontradas: $alternatives');
    
    return alternatives;
  }

  // 💾 SALVAR RESPOSTA DO USUÁRIO - agora usa o novo sistema
  Future<void> saveUserResponse({
    required int verseId,
    required String sessionId,
    required bool isCorrect,
    required String difficultyChosen,
    required List<String> alternatives,
    required int timeToAnswer,
    required int pointsEarned,
    String? bookName, // Novo parâmetro opcional
    int streakAtTime = 0, // Novo parâmetro opcional
  }) async {
    print('💾 Salvando resposta via novo sistema:');
    print('   - verseId: $verseId');
    print('   - sessionId: $sessionId');
    print('   - isCorrect: $isCorrect');
    print('   - difficultyChosen: "$difficultyChosen"');
    print('   - pointsEarned: $pointsEarned');
    
    // Usar o novo serviço para salvar resposta
    await _verseQuizService.saveUserResponse(
      verseId: verseId,
      bookName: bookName ?? 'Desconhecido',
      sessionId: sessionId,
      correct: isCorrect,
      difficulty: difficultyChosen,
      alternatives: alternatives,
      timeToAnswer: timeToAnswer,
      pointsEarned: pointsEarned,
      streakAtTime: streakAtTime,
    );
  }

  // 🎮 SESSÕES DE JOGO - agora usa o novo sistema de gamificação
  Future<void> saveGameSession(GameSessionModel session) async {
    final gameDb = await DatabaseHelper().gameManager.database;
    
    await gameDb.insert(
      'game_sessions', 
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> updateGameSession(GameSessionModel session) async {
    final gameDb = await DatabaseHelper().gameManager.database;
    
    await gameDb.update(
      'game_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }
  
  Future<GameSessionModel?> getActiveSession() async {
    final gameDb = await DatabaseHelper().gameManager.database;
    
    final result = await gameDb.query(
      'game_sessions',
      where: 'session_completed = 0',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return GameSessionModel.fromMap(result.first);
    }
    
    return null;
  }

  // 📊 ESTATÍSTICAS DIÁRIAS
  Future<void> updateDailyStats(GameSessionModel session) async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Verificar se já existe registro para hoje
    final existing = await db.query(
      'daily_stats',
      where: 'date = ?',
      whereArgs: [today],
    );
    
    if (existing.isEmpty) {
      // Criar novo registro
      final stats = DailyStatsModel(date: today);
      stats.updateWithSession(session);
      
      await db.insert('daily_stats', stats.toMap());
    } else {
      // Atualizar registro existente
      final stats = DailyStatsModel.fromMap(existing.first);
      stats.updateWithSession(session);
      
      await db.update(
        'daily_stats',
        stats.toMap(),
        where: 'date = ?',
        whereArgs: [today],
      );
    }
  }
  
  Future<bool> hasPlayedToday() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final result = await db.query(
      'daily_stats',
      where: 'date = ? AND sessions_played > 0',
      whereArgs: [today],
    );
    
    return result.isNotEmpty;
  }

  // 📈 BUSCAR ESTATÍSTICAS
  Future<Map<String, dynamic>> getOverallStats() async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        SUM(total_points) as total_points,
        SUM(total_questions) as total_questions,
        SUM(correct_answers) as total_correct,
        MAX(best_session_points) as best_session,
        COUNT(DISTINCT date) as days_played
      FROM daily_stats
      WHERE sessions_played > 0
    ''');
    
    if (result.isNotEmpty && result.first['total_questions'] != null) {
      final data = result.first;
      final totalQuestions = data['total_questions'] as int;
      final totalCorrect = data['total_correct'] as int;
      
      return {
        'total_points': data['total_points'] ?? 0,
        'total_questions': totalQuestions,
        'total_correct': totalCorrect,
        'accuracy': totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0,
        'best_session': data['best_session'] ?? 0,
        'days_played': data['days_played'] ?? 0,
      };
    }
    
    return {
      'total_points': 0,
      'total_questions': 0,
      'total_correct': 0,
      'accuracy': 0.0,
      'best_session': 0,
      'days_played': 0,
    };
  }
  
  Future<List<DailyStatsModel>> getRecentStats(int days) async {
    final db = await _dbHelper.database;
    
    final result = await db.query(
      'daily_stats',
      where: 'sessions_played > 0',
      orderBy: 'date DESC',
      limit: days,
    );
    
    return result.map((row) => DailyStatsModel.fromMap(row)).toList();
  }
  
  Future<Map<String, Map<String, int>>> getStatsByDifficulty() async {
    final db = await _dbHelper.database;
    
    print('🎯 Buscando estatísticas por dificuldade...');
    
    final result = await db.rawQuery('''
      SELECT 
        ur.difficulty_chosen,
        COUNT(*) as total_questions,
        SUM(CASE WHEN ur.correct = 1 THEN 1 ELSE 0 END) as correct_answers
      FROM user_responses ur
      GROUP BY ur.difficulty_chosen
    ''');
    
    print('🎯 Resultado da query: $result');
    
    final Map<String, Map<String, int>> stats = {};
    
    for (final row in result) {
      final difficulty = row['difficulty_chosen'] as String;
      final total = row['total_questions'] as int;
      final correct = row['correct_answers'] as int;
      
      print('   - Dificuldade: "$difficulty", Total: $total, Corretas: $correct');
      
      stats[difficulty] = {
        'total': total,
        'correct': correct,
      };
    }
    
    // Garantir que todas as dificuldades existam, mesmo com valores zero
    for (final difficulty in ['fácil', 'médio', 'difícil']) {
      if (!stats.containsKey(difficulty)) {
        stats[difficulty] = {'total': 0, 'correct': 0};
        print('   - Adicionada dificuldade vazia: "$difficulty"');
      }
    }
    
    print('🎯 Stats finais por dificuldade: $stats');
    return stats;
  }

  // 🏆 CONQUISTAS
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final db = await _dbHelper.database;
    
    return await db.query('achievements', orderBy: 'is_unlocked DESC, id ASC');
  }
  
  Future<void> unlockAchievement(String name) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'achievements',
      {
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'name = ? AND is_unlocked = 0',
      whereArgs: [name],
    );
  }

  // 🔧 UTILITÁRIOS
  Future<String?> getTestamentByBookName(String bookName) async {
    // Determinar testamento baseado no nome do livro (sem precisar de tabela testament)
    final oldTestamentBooks = {
      'Gênesis', 'Êxodo', 'Levítico', 'Números', 'Deuteronômio',
      'Josué', 'Juízes', 'Rute', '1 Samuel', '2 Samuel', '1 Reis', '2 Reis',
      '1 Crônicas', '2 Crônicas', 'Esdras', 'Neemias', 'Ester',
      'Jó', 'Salmos', 'Provérbios', 'Eclesiastes', 'Cânticos', 'Cantares',
      'Isaías', 'Jeremias', 'Lamentações', 'Ezequiel', 'Daniel',
      'Oséias', 'Joel', 'Amós', 'Obadias', 'Jonas', 'Miquéias',
      'Naum', 'Habacuque', 'Sofonias', 'Ageu', 'Zacarias', 'Malaquias'
    };
    
    return oldTestamentBooks.contains(bookName) ? 'AT' : 'NT';
  }
  
  Future<int> getEligibleVersesCount(String? difficulty) async {
    final db = await _dbHelper.database;
    
    String query = '''
      SELECT COUNT(*) as count
      FROM verse v
      JOIN book b ON v.book_id = b.id
      LEFT JOIN book_difficulty bd ON b.name = bd.book_name
      LEFT JOIN verse_quiz_data vqd ON v.id = vqd.verse_id
      WHERE LENGTH(v.text) BETWEEN 50 AND 300
    ''';
    
    List<dynamic> params = [];
    
    // Removemos temporariamente o filtro por dificuldade
    
    final result = await db.rawQuery(query, params);
    return result.first['count'] as int;
  }

  // 📖 BUSCAR CAPÍTULO COMPLETO
  Future<List<Map<String, dynamic>>> getChapterVerses({
    required String bookName,
    required int chapter,
  }) async {
    try {
      // Obter versão atual do usuário
      String currentVersion = await _settingsService.getCurrentBibleVersion();
      print('📖 Buscando capítulo $chapter de $bookName na versão $currentVersion');
      
      // Acessar o banco da versão específica
      final bibleDb = await DatabaseHelper().bibleManager.openBibleVersion(currentVersion);
      
      final result = await bibleDb.rawQuery('''
        SELECT v.verse as verse_number, v.text, v.id
        FROM verse v
        JOIN book b ON v.book_id = b.id
        WHERE b.name = ? AND v.chapter = ?
        ORDER BY v.verse ASC
      ''', [bookName, chapter]);
      
      print('✅ Encontrados ${result.length} versículos no capítulo $chapter de $bookName');
      return result;
    } catch (e) {
      print('❌ Erro ao buscar capítulo $chapter de $bookName: $e');
      return [];
    }
  }

  // 🧪 MÉTODO DEBUG - Verificar distribuição de livros
  Future<Map<String, int>> getBookDistribution() async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT b.name, COUNT(v.id) as verse_count
      FROM verse v
      JOIN book b ON v.book_id = b.id
      WHERE LENGTH(v.text) BETWEEN 50 AND 300
      GROUP BY b.name
      ORDER BY b.name
    ''');
    
    final Map<String, int> distribution = {};
    for (final row in result) {
      distribution[row['name'] as String] = row['verse_count'] as int;
    }
    
    return distribution;
  }

  // 🧪 MÉTODO DEBUG - Verificar primeiros 20 versículos elegíveis
  Future<List<Map<String, dynamic>>> getFirstEligibleVerses({int limit = 20}) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT v.id, b.name as book_name, v.chapter, v.verse, LENGTH(v.text) as text_length
      FROM verse v
      JOIN book b ON v.book_id = b.id
      WHERE LENGTH(v.text) BETWEEN 50 AND 300
      ORDER BY v.id
      LIMIT ?
    ''', [limit]);
    
    return result;
  }

  // ===== MÉTODOS PARA O LEITOR DE BÍBLIA =====

  /// Busca todos os livros disponíveis para uma versão específica
  Future<List<Map<String, dynamic>>> getAllBooks(String version) async {
    try {
      print('🔍 Buscando todos os livros para versão: $version');
      
      // Por enquanto, vamos sempre usar a lista padrão completa
      // para garantir que todos os 66 livros apareçam
      List<Map<String, dynamic>> allBooks = _getDefaultBooks();
      
      print('✅ Retornando ${allBooks.length} livros completos');
      print('📚 Livros: ${allBooks.map((b) => b['name']).take(10).join(', ')}...');
      
      return allBooks;
    } catch (e) {
      print('❌ Erro ao buscar livros: $e');
      return _getDefaultBooks();
    }
  }

  /// Busca todos os versículos de um capítulo específico
  Future<List<Map<String, dynamic>>> getVersesByChapter(String version, String bookName, int chapter) async {
    try {
      print('🔍 Buscando versículos: $bookName capítulo $chapter (versão: $version)');
      
      // Método 1: Tentar buscar diretamente do banco da versão específica
      final bibleManager = DatabaseHelper().bibleManager;
      final bibleDb = await bibleManager.openBibleVersion(version.toUpperCase());
      
      // Tentar diferentes estruturas de query
      List<String> queries = [
        // Query 1: estrutura com tabelas relacionadas
        '''SELECT verse as verse_number, text
           FROM verse v
           JOIN book b ON v.book_id = b.id
           WHERE b.name = ? AND v.chapter = ?
           ORDER BY v.verse''',
        
        // Query 2: estrutura simples com campos diretos
        '''SELECT verse, text
           FROM verse
           WHERE book = ? AND chapter = ?
           ORDER BY verse''',
           
        // Query 3: estrutura com verse_number
        '''SELECT verse_number as verse, text
           FROM verses
           WHERE book_name = ? AND chapter_number = ?
           ORDER BY verse_number''',
      ];
      
      for (String query in queries) {
        try {
          final result = await bibleDb.rawQuery(query, [bookName, chapter]);
          if (result.isNotEmpty) {
            print('✅ Método direto: ${result.length} versículos encontrados para $bookName $chapter');
            return result.map((row) => {
              'verse': row['verse'] ?? row['verse_number'] ?? 1,
              'text': row['text'] ?? '',
            }).toList();
          }
        } catch (e) {
          print('⚠️ Query falhou: $e');
          continue;
        }
      }
      
      // Método 2: Fallback usando verse_quiz_data como ponte
      final gameDb = await DatabaseHelper().gameManager.database;
      
      final verseIds = await gameDb.rawQuery('''
        SELECT verse_id, verse_number
        FROM verse_quiz_data 
        WHERE book_name = ? AND chapter = ?
        ORDER BY verse_number
      ''', [bookName, chapter]);
      
      if (verseIds.isNotEmpty) {
        print('🔗 Usando verse_quiz_data como ponte: ${verseIds.length} IDs encontrados');
        
        List<Map<String, dynamic>> verses = [];
        for (var row in verseIds) {
          int verseId = row['verse_id'] as int;
          int verseNumber = row['verse_number'] as int;
          
          var verseData = await bibleManager.getVerse(version.toUpperCase(), verseId);
          
          if (verseData != null && verseData['text'] != null) {
            verses.add({
              'verse': verseNumber,
              'text': verseData['text'],
            });
          }
        }
        
        if (verses.isNotEmpty) {
          print('✅ Ponte: ${verses.length} versículos encontrados para $bookName $chapter');
          return verses;
        }
      }
      
      // Método 3: Última tentativa - gerar versículos de exemplo
      print('⚠️ Nenhum método funcionou, gerando versículos de exemplo para $bookName $chapter');
      
      // Usar número típico de versículos por capítulo baseado no livro
      int estimatedVerses = _getEstimatedVersesForChapter(bookName, chapter);
      
      List<Map<String, dynamic>> exampleVerses = [];
      for (int i = 1; i <= estimatedVerses; i++) {
        exampleVerses.add({
          'verse': i,
          'text': 'Texto do versículo $i não disponível na versão $version. Verifique a instalação da versão bíblica.',
        });
      }
      
      print('📝 Gerados $estimatedVerses versículos de exemplo para $bookName $chapter');
      return exampleVerses;
      
    } catch (e) {
      print('❌ Erro geral ao buscar versículos: $e');
      return [];
    }
  }

  /// Estima o número de versículos em um capítulo baseado no conhecimento bíblico
  int _getEstimatedVersesForChapter(String bookName, int chapter) {
    // Alguns casos especiais conhecidos
    Map<String, Map<int, int>> specialCases = {
      'Salmos': {119: 176}, // Salmo 119 tem 176 versículos
      'Gênesis': {1: 31, 2: 25, 3: 24},
      'João': {3: 36, 14: 31, 17: 26},
      'Mateus': {5: 48, 6: 34, 7: 29},
    };
    
    if (specialCases.containsKey(bookName) && 
        specialCases[bookName]!.containsKey(chapter)) {
      return specialCases[bookName]![chapter]!;
    }
    
    // Estimativas gerais por tipo de livro
    if (bookName == 'Salmos') return 20; // Média dos salmos
    if (bookName.contains('Crônicas')) return 35;
    if (['Gênesis', 'Êxodo', 'Números'].contains(bookName)) return 30;
    if (['Mateus', 'Lucas', 'Atos'].contains(bookName)) return 25;
    if (['Marcos', 'João'].contains(bookName)) return 20;
    if (bookName.contains('Coríntios')) return 15;
    if (['2 João', '3 João', 'Filemom', 'Judas'].contains(bookName)) return 5;
    
    return 15; // Padrão geral
  }

  /// Dados dos livros bíblicos padrão com número correto de capítulos
  List<Map<String, dynamic>> _getDefaultBooks() {
    return [
      // Antigo Testamento
      {'name': 'Gênesis', 'chapters': 50, 'testament': 'AT'},
      {'name': 'Êxodo', 'chapters': 40, 'testament': 'AT'},
      {'name': 'Levítico', 'chapters': 27, 'testament': 'AT'},
      {'name': 'Números', 'chapters': 36, 'testament': 'AT'},
      {'name': 'Deuteronômio', 'chapters': 34, 'testament': 'AT'},
      {'name': 'Josué', 'chapters': 24, 'testament': 'AT'},
      {'name': 'Juízes', 'chapters': 21, 'testament': 'AT'},
      {'name': 'Rute', 'chapters': 4, 'testament': 'AT'},
      {'name': '1 Samuel', 'chapters': 31, 'testament': 'AT'},
      {'name': '2 Samuel', 'chapters': 24, 'testament': 'AT'},
      {'name': '1 Reis', 'chapters': 22, 'testament': 'AT'},
      {'name': '2 Reis', 'chapters': 25, 'testament': 'AT'},
      {'name': '1 Crônicas', 'chapters': 29, 'testament': 'AT'},
      {'name': '2 Crônicas', 'chapters': 36, 'testament': 'AT'},
      {'name': 'Esdras', 'chapters': 10, 'testament': 'AT'},
      {'name': 'Neemias', 'chapters': 13, 'testament': 'AT'},
      {'name': 'Ester', 'chapters': 10, 'testament': 'AT'},
      {'name': 'Jó', 'chapters': 42, 'testament': 'AT'},
      {'name': 'Salmos', 'chapters': 150, 'testament': 'AT'},
      {'name': 'Provérbios', 'chapters': 31, 'testament': 'AT'},
      {'name': 'Eclesiastes', 'chapters': 12, 'testament': 'AT'},
      {'name': 'Cantares', 'chapters': 8, 'testament': 'AT'},
      {'name': 'Isaías', 'chapters': 66, 'testament': 'AT'},
      {'name': 'Jeremias', 'chapters': 52, 'testament': 'AT'},
      {'name': 'Lamentações', 'chapters': 5, 'testament': 'AT'},
      {'name': 'Ezequiel', 'chapters': 48, 'testament': 'AT'},
      {'name': 'Daniel', 'chapters': 12, 'testament': 'AT'},
      {'name': 'Oséias', 'chapters': 14, 'testament': 'AT'},
      {'name': 'Joel', 'chapters': 3, 'testament': 'AT'},
      {'name': 'Amós', 'chapters': 9, 'testament': 'AT'},
      {'name': 'Obadias', 'chapters': 1, 'testament': 'AT'},
      {'name': 'Jonas', 'chapters': 4, 'testament': 'AT'},
      {'name': 'Miquéias', 'chapters': 7, 'testament': 'AT'},
      {'name': 'Naum', 'chapters': 3, 'testament': 'AT'},
      {'name': 'Habacuque', 'chapters': 3, 'testament': 'AT'},
      {'name': 'Sofonias', 'chapters': 3, 'testament': 'AT'},
      {'name': 'Ageu', 'chapters': 2, 'testament': 'AT'},
      {'name': 'Zacarias', 'chapters': 14, 'testament': 'AT'},
      {'name': 'Malaquias', 'chapters': 4, 'testament': 'AT'},
      
      // Novo Testamento
      {'name': 'Mateus', 'chapters': 28, 'testament': 'NT'},
      {'name': 'Marcos', 'chapters': 16, 'testament': 'NT'},
      {'name': 'Lucas', 'chapters': 24, 'testament': 'NT'},
      {'name': 'João', 'chapters': 21, 'testament': 'NT'},
      {'name': 'Atos', 'chapters': 28, 'testament': 'NT'},
      {'name': 'Romanos', 'chapters': 16, 'testament': 'NT'},
      {'name': '1 Coríntios', 'chapters': 16, 'testament': 'NT'},
      {'name': '2 Coríntios', 'chapters': 13, 'testament': 'NT'},
      {'name': 'Gálatas', 'chapters': 6, 'testament': 'NT'},
      {'name': 'Efésios', 'chapters': 6, 'testament': 'NT'},
      {'name': 'Filipenses', 'chapters': 4, 'testament': 'NT'},
      {'name': 'Colossenses', 'chapters': 4, 'testament': 'NT'},
      {'name': '1 Tessalonicenses', 'chapters': 5, 'testament': 'NT'},
      {'name': '2 Tessalonicenses', 'chapters': 3, 'testament': 'NT'},
      {'name': '1 Timóteo', 'chapters': 6, 'testament': 'NT'},
      {'name': '2 Timóteo', 'chapters': 4, 'testament': 'NT'},
      {'name': 'Tito', 'chapters': 3, 'testament': 'NT'},
      {'name': 'Filemom', 'chapters': 1, 'testament': 'NT'},
      {'name': 'Hebreus', 'chapters': 13, 'testament': 'NT'},
      {'name': 'Tiago', 'chapters': 5, 'testament': 'NT'},
      {'name': '1 Pedro', 'chapters': 5, 'testament': 'NT'},
      {'name': '2 Pedro', 'chapters': 3, 'testament': 'NT'},
      {'name': '1 João', 'chapters': 5, 'testament': 'NT'},
      {'name': '2 João', 'chapters': 1, 'testament': 'NT'},
      {'name': '3 João', 'chapters': 1, 'testament': 'NT'},
      {'name': 'Judas', 'chapters': 1, 'testament': 'NT'},
      {'name': 'Apocalipse', 'chapters': 22, 'testament': 'NT'},
    ];
  }

  /// Busca informações de um livro específico
  Future<Map<String, dynamic>?> getBookInfo(String version, String bookName) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        b.name,
        COUNT(DISTINCT v.chapter) as chapters,
        COUNT(v.id) as total_verses,
        CASE WHEN b.id <= 39 THEN 'AT' ELSE 'NT' END as testament
      FROM book b
      JOIN verse v ON b.id = v.book_id
      WHERE v.version = ? AND b.name = ?
      GROUP BY b.id, b.name
    ''', [version, bookName]);
    
    return result.isNotEmpty ? result.first : null;
  }
}
