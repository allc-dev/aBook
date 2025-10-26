import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/reading_history_model.dart';
import '../models/reading_stats_model.dart';

/// Serviço para gerenciar histórico de leitura e estatísticas
class ReadingHistoryService {
  static final ReadingHistoryService _instance = ReadingHistoryService._internal();
  factory ReadingHistoryService() => _instance;
  ReadingHistoryService._internal();

  /// Registra a leitura de um capítulo
  Future<bool> recordChapterRead({
    required String bookName,
    required int chapter,
    required String bibleVersion,
  }) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      // Verificar se já foi registrada a leitura deste capítulo hoje
      final existing = await gameDb.query(
        'reading_history',
        where: 'book_name = ? AND chapter = ? AND read_date = ?',
        whereArgs: [bookName, chapter, todayStr],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        print('📚 Capítulo $bookName $chapter já foi lido hoje');
        return false; // Já registrado hoje
      }

      // Registrar nova leitura
      final reading = ReadingHistoryModel(
        bookName: bookName,
        chapter: chapter,
        bibleVersion: bibleVersion,
        readDate: today,
        pointsEarned: 10, // 10 pontos por capítulo
      );

      await gameDb.insert('reading_history', reading.toMap());

      // Atualizar pontos totais do usuário
      await _updateUserTotalPoints(10);

      // Adicionar XP ao jogador
      await _updateUserExperience(10);

      // Verificar e atualizar conquistas relacionadas à leitura
      await _checkReadingAchievements();

      print('✅ Leitura registrada: $bookName capítulo $chapter (+10 pontos)');
      return true;

    } catch (e) {
      print('❌ Erro ao registrar leitura: $e');
      return false;
    }
  }

  /// Atualiza os pontos totais do usuário
  Future<void> _updateUserTotalPoints(int pointsToAdd) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.rawUpdate('''
        UPDATE user_progress 
        SET total_points = total_points + ?,
            updated_at = ?
        WHERE id = 1
      ''', [pointsToAdd, DateTime.now().toIso8601String()]);
      
    } catch (e) {
      print('❌ Erro ao atualizar pontos: $e');
    }
  }

  /// Atualiza a experiência total do usuário
  Future<void> _updateUserExperience(int xpToAdd) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.rawUpdate('''
        UPDATE user_progress 
        SET total_experience = total_experience + ?,
            updated_at = ?
        WHERE id = 1
      ''', [xpToAdd, DateTime.now().toIso8601String()]);
      
    } catch (e) {
      print('❌ Erro ao atualizar XP: $e');
    }
  }

  /// Verifica e desbloqueia conquistas relacionadas à leitura
  Future<void> _checkReadingAchievements() async {
    try {
      final stats = await getReadingStats();

      // Conquista: Primeiro Capítulo
      if (stats.totalChaptersRead == 1) {
        await _unlockAchievement('Primeiro Leitor', 'Leu seu primeiro capítulo da Bíblia');
      }

      // Conquista: 10 Capítulos
      if (stats.totalChaptersRead == 10) {
        await _unlockAchievement('Leitor Iniciante', 'Leu 10 capítulos da Bíblia');
      }

      // Conquista: 50 Capítulos
      if (stats.totalChaptersRead == 50) {
        await _unlockAchievement('Leitor Dedicado', 'Leu 50 capítulos da Bíblia');
      }

      // Conquista: 100 Capítulos
      if (stats.totalChaptersRead == 100) {
        await _unlockAchievement('Estudioso', 'Leu 100 capítulos da Bíblia');
      }

      // Conquista: Streak de 7 dias
      if (stats.currentStreak == 7) {
        await _unlockAchievement('Disciplinado', 'Leu por 7 dias consecutivos');
      }

      // Conquista: Streak de 30 dias
      if (stats.currentStreak == 30) {
        await _unlockAchievement('Perseverante', 'Leu por 30 dias consecutivos');
      }

      // Conquista: 10 livros diferentes
      if (stats.totalBooksStarted == 10) {
        await _unlockAchievement('Explorador', 'Leu capítulos de 10 livros diferentes');
      }

      // Conquista: Livro completo
      if (stats.totalBooksCompleted >= 1) {
        await _unlockAchievement('Completista', 'Leu um livro da Bíblia por inteiro');
      }

    } catch (e) {
      print('❌ Erro ao verificar conquistas de leitura: $e');
    }
  }

  /// Desbloqueia uma conquista
  Future<void> _unlockAchievement(String name, String description) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      // Verificar se já foi desbloqueada
      final existing = await gameDb.query(
        'achievements',
        where: 'name = ? AND is_unlocked = 1',
        whereArgs: [name],
        limit: 1,
      );

      if (existing.isNotEmpty) return; // Já desbloqueada

      // Inserir ou atualizar conquista
      await gameDb.rawUpdate('''
        INSERT OR REPLACE INTO achievements (name, description, is_unlocked, unlocked_at)
        VALUES (?, ?, 1, ?)
      ''', [name, description, DateTime.now().toIso8601String()]);

      print('🏆 Conquista desbloqueada: $name - $description');

    } catch (e) {
      print('❌ Erro ao desbloquear conquista: $e');
    }
  }

  /// Obtém estatísticas completas de leitura
  Future<ReadingStatsModel> getReadingStats() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      // 1. Contar dias únicos de leitura
      final daysResult = await gameDb.rawQuery('''
        SELECT COUNT(DISTINCT read_date) as total_days
        FROM reading_history
      ''');
      final totalDays = (daysResult.first['total_days'] as int?) ?? 0;

      // 2. Contar total de capítulos lidos
      final chaptersResult = await gameDb.rawQuery('''
        SELECT COUNT(*) as total_chapters
        FROM reading_history
      ''');
      final totalChapters = (chaptersResult.first['total_chapters'] as int?) ?? 0;

      // 3. Contar livros únicos iniciados
      final booksResult = await gameDb.rawQuery('''
        SELECT COUNT(DISTINCT book_name) as total_books
        FROM reading_history
      ''');
      final totalBooks = (booksResult.first['total_books'] as int?) ?? 0;

      // 4. Calcular pontos totais da leitura
      final pointsResult = await gameDb.rawQuery('''
        SELECT SUM(points_earned) as total_points
        FROM reading_history
      ''');
      final totalPoints = (pointsResult.first['total_points'] as int?) ?? 0;

      // 5. Último dia de leitura
      final lastReadResult = await gameDb.rawQuery('''
        SELECT MAX(read_date) as last_date
        FROM reading_history
      ''');
      final lastDateStr = lastReadResult.first['last_date'] as String?;
      final lastReadDate = lastDateStr != null ? DateTime.parse(lastDateStr) : null;

      // 6. Calcular streaks
      final streaks = await _calculateReadingStreaks();

      // 7. Progresso por livro
      final bookProgress = await _getBookProgress();

      // 8. Livros favoritos (mais lidos)
      final favoriteBooks = await _getFavoriteBooks();

      // 9. Leituras por mês
      final readingByMonth = await _getReadingsByMonth();

      // 10. Calcular livros completos (assumindo estrutura padrão da Bíblia)
      final booksCompleted = await _getBooksCompleted();

      return ReadingStatsModel(
        totalDaysReading: totalDays,
        currentStreak: streaks['current'] ?? 0,
        longestStreak: streaks['longest'] ?? 0,
        totalChaptersRead: totalChapters,
        totalBooksStarted: totalBooks,
        totalBooksCompleted: booksCompleted,
        totalPointsFromReading: totalPoints,
        lastReadingDate: lastReadDate,
        bookProgress: bookProgress,
        favoriteBooks: favoriteBooks,
        readingByMonth: readingByMonth,
      );

    } catch (e) {
      print('❌ Erro ao calcular estatísticas de leitura: $e');
      return ReadingStatsModel();
    }
  }

  /// Calcula streaks de leitura (dias consecutivos)
  Future<Map<String, int>> _calculateReadingStreaks() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      // Buscar todos os dias únicos de leitura ordenados
      final daysResult = await gameDb.rawQuery('''
        SELECT DISTINCT read_date
        FROM reading_history
        ORDER BY read_date DESC
      ''');

      if (daysResult.isEmpty) {
        return {'current': 0, 'longest': 0};
      }

      final dates = daysResult
          .map((row) => DateTime.parse(row['read_date'] as String))
          .toList();

      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 1;

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Verificar se leu hoje ou ontem para streak atual
      if (dates.first.day == today.day && dates.first.month == today.month && dates.first.year == today.year) {
        currentStreak = 1; // Leu hoje
      } else if (dates.first.day == yesterday.day && dates.first.month == yesterday.month && dates.first.year == yesterday.year) {
        currentStreak = 1; // Leu ontem
      } else {
        currentStreak = 0; // Não leu hoje nem ontem, streak quebrado
      }

      // Calcular streak atual e maior streak
      for (int i = 1; i < dates.length; i++) {
        final current = dates[i - 1];
        final previous = dates[i];
        
        final diff = current.difference(previous).inDays;
        
        if (diff == 1) {
          // Dias consecutivos
          tempStreak++;
          if (currentStreak > 0) currentStreak++;
        } else {
          // Streak quebrado
          longestStreak = math.max(longestStreak, tempStreak);
          tempStreak = 1;
          if (currentStreak > 0 && i == 1) {
            // Se é a primeira quebra e temos streak atual, mantê-lo
          } else {
            currentStreak = 0;
          }
        }
      }

      longestStreak = math.max(longestStreak, tempStreak);

      return {
        'current': currentStreak,
        'longest': longestStreak,
      };

    } catch (e) {
      print('❌ Erro ao calcular streaks: $e');
      return {'current': 0, 'longest': 0};
    }
  }

  /// Obtém progresso de leitura por livro
  Future<Map<String, int>> _getBookProgress() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      final result = await gameDb.rawQuery('''
        SELECT book_name, COUNT(*) as chapters_read
        FROM reading_history
        GROUP BY book_name
        ORDER BY chapters_read DESC
      ''');

      return Map.fromEntries(
        result.map((row) => MapEntry(
          row['book_name'] as String,
          row['chapters_read'] as int,
        ))
      );

    } catch (e) {
      print('❌ Erro ao calcular progresso por livro: $e');
      return {};
    }
  }

  /// Obtém os 5 livros mais lidos
  Future<List<String>> _getFavoriteBooks() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      final result = await gameDb.rawQuery('''
        SELECT book_name, COUNT(*) as chapters_read
        FROM reading_history
        GROUP BY book_name
        ORDER BY chapters_read DESC
        LIMIT 5
      ''');

      return result.map((row) => row['book_name'] as String).toList();

    } catch (e) {
      print('❌ Erro ao buscar livros favoritos: $e');
      return [];
    }
  }

  /// Obtém leituras dos últimos 6 meses
  Future<Map<String, int>> _getReadingsByMonth() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;

      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final sixMonthsAgoStr = sixMonthsAgo.toIso8601String().split('T')[0];

      final result = await gameDb.rawQuery('''
        SELECT substr(read_date, 1, 7) as month, COUNT(*) as readings
        FROM reading_history
        WHERE read_date >= ?
        GROUP BY month
        ORDER BY month DESC
      ''', [sixMonthsAgoStr]);

      return Map.fromEntries(
        result.map((row) => MapEntry(
          row['month'] as String,
          row['readings'] as int,
        ))
      );

    } catch (e) {
      print('❌ Erro ao buscar leituras por mês: $e');
      return {};
    }
  }

  /// Calcula quantos livros foram lidos completamente
  /// (Esta é uma aproximação baseada em capítulos conhecidos da Bíblia)
  Future<int> _getBooksCompleted() async {
    try {
      // Mapa com número de capítulos por livro da Bíblia
      final booksChapters = {
        'Gênesis': 50, 'Êxodo': 40, 'Levítico': 27, 'Números': 36, 'Deuteronômio': 34,
        'Josué': 24, 'Juízes': 21, 'Rute': 4, '1 Samuel': 31, '2 Samuel': 24,
        '1 Reis': 22, '2 Reis': 25, '1 Crônicas': 29, '2 Crônicas': 36, 'Esdras': 10,
        'Neemias': 13, 'Ester': 10, 'Jó': 42, 'Salmos': 150, 'Provérbios': 31,
        'Eclesiastes': 12, 'Cânticos': 8, 'Cantares': 8, 'Isaías': 66, 'Jeremias': 52,
        'Lamentações': 5, 'Ezequiel': 48, 'Daniel': 12, 'Oséias': 14, 'Joel': 3,
        'Amós': 9, 'Obadias': 1, 'Jonas': 4, 'Miquéias': 7, 'Naum': 3,
        'Habacuque': 3, 'Sofonias': 3, 'Ageu': 2, 'Zacarias': 14, 'Malaquias': 4,
        'Mateus': 28, 'Marcos': 16, 'Lucas': 24, 'João': 21, 'Atos': 28,
        'Romanos': 16, '1 Coríntios': 16, '2 Coríntios': 13, 'Gálatas': 6, 'Efésios': 6,
        'Filipenses': 4, 'Colossenses': 4, '1 Tessalonicenses': 5, '2 Tessalonicenses': 3,
        '1 Timóteo': 6, '2 Timóteo': 4, 'Tito': 3, 'Filemom': 1, 'Hebreus': 13,
        'Tiago': 5, '1 Pedro': 5, '2 Pedro': 3, '1 João': 5, '2 João': 1,
        '3 João': 1, 'Judas': 1, 'Apocalipse': 22,
      };

      final bookProgress = await _getBookProgress();
      int completedBooks = 0;

      for (final entry in bookProgress.entries) {
        final bookName = entry.key;
        final chaptersRead = entry.value;
        final totalChapters = booksChapters[bookName];

        if (totalChapters != null && chaptersRead >= totalChapters) {
          completedBooks++;
        }
      }

      return completedBooks;

    } catch (e) {
      print('❌ Erro ao calcular livros completos: $e');
      return 0;
    }
  }

  /// Obtém histórico de leitura recente (últimos 30 dias)
  Future<List<ReadingHistoryModel>> getRecentReadings({int days = 30}) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = cutoffDate.toIso8601String().split('T')[0];

      final result = await gameDb.query(
        'reading_history',
        where: 'read_date >= ?',
        whereArgs: [cutoffStr],
        orderBy: 'read_date DESC, book_name ASC, chapter ASC',
      );

      return result.map((row) => ReadingHistoryModel.fromMap(row)).toList();

    } catch (e) {
      print('❌ Erro ao buscar histórico recente: $e');
      return [];
    }
  }

  /// Remove todos os registros de leitura (para reset/debug)
  Future<void> clearAllReadingHistory() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      await gameDb.delete('reading_history');
      print('🗑️ Histórico de leitura limpo');
    } catch (e) {
      print('❌ Erro ao limpar histórico: $e');
    }
  }

  /// Verifica se hoje é um novo recorde de leitura
  Future<bool> isNewDailyRecord() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final todayCount = await gameDb.rawQuery('''
        SELECT COUNT(*) as count
        FROM reading_history
        WHERE read_date = ?
      ''', [today]);

      final maxCount = await gameDb.rawQuery('''
        SELECT MAX(daily_count) as max_count
        FROM (
          SELECT COUNT(*) as daily_count
          FROM reading_history
          GROUP BY read_date
        )
      ''');

      final todayReads = (todayCount.first['count'] as int?) ?? 0;
      final previousMax = (maxCount.first['max_count'] as int?) ?? 0;

      return todayReads > previousMax;

    } catch (e) {
      print('❌ Erro ao verificar recorde diário: $e');
      return false;
    }
  }
}
