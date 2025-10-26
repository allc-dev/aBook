import '../database/database_helper.dart';
import '../services/bible_settings_service.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

/// Service para buscar versículos usando a versão atual escolhida pelo usuário
class VerseQuizService {
  static final VerseQuizService _instance = VerseQuizService._internal();
  factory VerseQuizService() => _instance;
  VerseQuizService._internal();

  /// Busca versículos para o quiz usando a versão atual escolhida pelo usuário
  Future<List<Map<String, dynamic>>> getQuizVerses(String difficulty, {int limit = 10}) async {
    try {
      // 1. Obter versão atual escolhida pelo usuário
      String currentVersion = await BibleSettingsService().getCurrentBibleVersion();
      print('📖 Versão da Bíblia atual: $currentVersion');
      
      // 2. Buscar versículos elegíveis para quiz no banco de gamificação
      final gameDb = await DatabaseHelper().gameManager.database;

  // 🔎 Garantir diversidade mínima de livros antes de selecionar
  await _expandVerseQuizDataIfSkewed(currentVersion);
      
      // Debug: verificar quantos versículos temos disponíveis
      final totalVerses = await gameDb.rawQuery('SELECT COUNT(*) as count FROM verse_quiz_data');
      print('📊 Total de versículos na tabela verse_quiz_data: ${totalVerses.first['count']}');
      
      // Debug: listar alguns livros disponíveis
      final sampleVerses = await gameDb.rawQuery('SELECT DISTINCT book_name FROM verse_quiz_data LIMIT 10');
      print('📚 Livros disponíveis: ${sampleVerses.map((e) => e['book_name']).join(', ')}');
      // Debug extra: distribuição por usage_count (top 5 livros com menor uso)
      final dist = await gameDb.rawQuery('''
        SELECT book_name, COUNT(*) total,
               SUM(CASE WHEN last_used_date IS NULL THEN 1 ELSE 0 END) sem_uso,
               MIN(usage_count) min_u, MAX(usage_count) max_u, AVG(usage_count) media_u
        FROM verse_quiz_data
        GROUP BY book_name
        ORDER BY min_u ASC
        LIMIT 8
      ''');
      for (var row in dist) {
        print('📊 Livro ${row['book_name']}: total=${row['total']} sem_uso=${row['sem_uso']} usage[min=${row['min_u']},max=${row['max_u']},avg=${row['media_u']}]');
      }
      

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7)).toIso8601String();
      final threeDaysAgo = now.subtract(const Duration(days: 3)).toIso8601String();
      final oneDayAgo = now.subtract(const Duration(days: 1)).toIso8601String();
      final rand = Random();

      Future<List<Map<String, dynamic>>> getBooks(String thresholdIso) async {
        // Pega livros inclusive os que não estão em book_difficulty para não limitar à lista inicial
        return await gameDb.rawQuery('''
          SELECT DISTINCT vqd.book_name,
            COALESCE(bd.testament_type,
              CASE
                WHEN vqd.book_name IN ('Gênesis','Êxodo','Levítico','Números','Deuteronômio','Josué','Juízes','Rute','1 Samuel','2 Samuel','1 Reis','2 Reis','1 Crônicas','2 Crônicas','Esdras','Neemias','Ester','Jó','Salmos','Provérbios','Eclesiastes','Cânticos','Cantares','Isaías','Jeremias','Lamentações','Ezequiel','Daniel','Oséias','Joel','Amós','Obadias','Jonas','Miquéias','Naum','Habacuque','Sofonias','Ageu','Zacarias','Malaquias') THEN 'AT' ELSE 'NT' END
            ) as testament_type,
            MIN(vqd.usage_count) as min_usage
          FROM verse_quiz_data vqd
          LEFT JOIN book_difficulty bd ON bd.book_name = vqd.book_name
          WHERE vqd.is_quiz_eligible = 1
            AND (vqd.last_used_date IS NULL OR vqd.last_used_date < ?)
          GROUP BY vqd.book_name, testament_type
          ORDER BY min_usage ASC, RANDOM()
        ''', [thresholdIso]);
      }

      Future<Map<String, dynamic>?> pickVerseFromBook(String book, String thresholdIso) async {
        final rows = await gameDb.rawQuery('''
          SELECT * FROM verse_quiz_data
          WHERE is_quiz_eligible = 1
            AND book_name = ?
            AND (last_used_date IS NULL OR last_used_date < ?)
            AND chapter IS NOT NULL
            AND verse_number IS NOT NULL
            AND verse_id IS NOT NULL
          ORDER BY usage_count ASC, RANDOM()
          LIMIT 4
        ''', [book, thresholdIso]);
        if (rows.isEmpty) return null;
        return rows[rand.nextInt(rows.length)];
      }

      List<Map<String, dynamic>> selected = [];
      Set<int> selectedIds = {};

      Future<void> fill(String thresholdIso) async {
        if (selected.length >= limit) return;
        final books = await getBooks(thresholdIso);
        if (books.isEmpty) return;
        var atBooks = books.where((b) => b['testament_type'] == 'AT').map((e) => e['book_name'] as String).toList();
        var ntBooks = books.where((b) => b['testament_type'] == 'NT').map((e) => e['book_name'] as String).toList();
        // Se algum lado está vazio, tentar repovoar sem filtro de testamento para não travar
        if (atBooks.isEmpty || ntBooks.isEmpty) {
          print('⚠️ Um testamento está vazio para threshold $thresholdIso (AT=${atBooks.length}, NT=${ntBooks.length})');
        }
        atBooks.shuffle(rand);
        ntBooks.shuffle(rand);
        bool startAT = rand.nextBool();
        int ai = 0, ni = 0;
        while (selected.length < limit && (ai < atBooks.length || ni < ntBooks.length)) {
          bool pickAT;
          if (ai >= atBooks.length) {
            pickAT = false;
          } else if (ni >= ntBooks.length) {
            pickAT = true;
          } else {
            pickAT = startAT ? (selected.length % 2 == 0) : (selected.length % 2 == 1);
          }
          final book = pickAT ? atBooks[ai++] : ntBooks[ni++];
          final verse = await pickVerseFromBook(book, thresholdIso);
          if (verse != null) {
            final id = verse['verse_id'] as int;
            if (!selectedIds.contains(id)) {
              selected.add(verse);
              selectedIds.add(id);
              if (selected.length % 5 == 0) {
                print('🧪 Parcial: ${selected.length} selecionados (último livro=$book)');
              }
            }
          }
        }
      };

      await fill(sevenDaysAgo);
      if (selected.length < limit) await fill(threeDaysAgo);
      if (selected.length < limit) await fill(oneDayAgo);

      // Fallback final SEM filtro de data (pega o que faltar)
      if (selected.length < limit) {
        final need = limit - selected.length;
        final rows = await gameDb.rawQuery('''
          SELECT * FROM verse_quiz_data
          WHERE is_quiz_eligible = 1
            AND chapter IS NOT NULL
            AND verse_number IS NOT NULL
            AND verse_id IS NOT NULL
          ORDER BY usage_count ASC, RANDOM()
          LIMIT ?
        ''', [need * 3]);
        for (var r in rows) {
          if (selected.length >= limit) break;
          final id = r['verse_id'] as int;
          if (!selectedIds.contains(id)) {
            selected.add(r);
            selectedIds.add(id);
          }
        }
      }

      selected.shuffle(rand);

      final verses = selected;
      print('🔍 Seleção final de versículos: ${verses.length}/$limit (únicos, balanceados)');
      if (verses.isEmpty) {
        print('⚠️ Nenhum versículo encontrado após todos os fallbacks.');
        return [];
      }
      if (verses.length < limit) {
        print('⚠️ Aviso: não atingiu o limite. Faltaram ${limit - verses.length}.');
      }
      // ===================== FIM NOVO ALGORITMO =====================
      
      // 3. Buscar texto real dos versículos na versão escolhida
      List<Map<String, dynamic>> quizVerses = [];
      for (var verseData in verses) {
        int verseId = verseData['verse_id'] as int;
        var verseText = await DatabaseHelper().bibleManager.getVerse(currentVersion, verseId);
        
        if (verseText != null) {
          // 🚨 VALIDAÇÃO: Verificar se os dados básicos não são null
          final expectedChapter = verseData['chapter'];
          final expectedVerse = verseData['verse_number'];
          
          if (expectedChapter == null || expectedVerse == null) {
            print('🚨❌ DADOS INCONSISTENTES: capítulo ou versículo é null para verse_id=$verseId');
            print('   - book_name: ${verseData['book_name']}');
            print('   - chapter: $expectedChapter');
            print('   - verse_number: $expectedVerse');
            continue; // Pular este versículo
          }
          
          // 🚨 DEBUG: Comparar dados esperados vs retornados
          if (verseText['chapter'] != expectedChapter || verseText['verse'] != expectedVerse) {
            print('🚨❌ INCONSISTÊNCIA DETECTADA!');
            print('   - Esperado: capítulo $expectedChapter, versículo $expectedVerse');
            print('   - Retornado: capítulo ${verseText['chapter']}, versículo ${verseText['verse']}');
            print('   - Texto: "${verseText['text']}"');
            
            // CORREÇÃO: Buscar o versículo correto pelo livro, capítulo e número
            var correctVerse = await _getCorrectVerse(currentVersion, verseData['book_name'], expectedChapter, expectedVerse);
            if (correctVerse != null) {
              print('✅ CORREÇÃO APLICADA: Usando versículo correto');
              verseText = correctVerse;
              
              // Atualizar o verse_id na tabela para corrigir a inconsistência
              await _updateVerseIdInQuizData(verseId, correctVerse['id']);
            } else {
              print('❌ CORREÇÃO FALHOU: Não foi possível encontrar o versículo correto');
              continue; // Pular este versículo
            }
          }
          
          quizVerses.add({
            ...verseData,
            'text': verseText['text'],
            'bible_version': currentVersion,
          });
          
          // Incrementar contador de uso
          await _incrementUsageCount(verseId);
        }
      }
      
      print('✅ Encontrados ${quizVerses.length} versículos para quiz (versão: $currentVersion)');
      return quizVerses;
      
    } catch (e) {
      print('❌ Erro ao buscar versículos para quiz: $e');
      return [];
    }
  }

  /// Garante que a tabela verse_quiz_data não esteja enviesada só nos primeiros livros.
  /// Estratégia: se DISTINCT(book_name) < 30, buscar livros faltantes e inserir versos deles.
  Future<void> _expandVerseQuizDataIfSkewed(String referenceVersion) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      final distinctCountRow = await gameDb.rawQuery('SELECT COUNT(DISTINCT book_name) as c FROM verse_quiz_data');
      final distinctCount = (distinctCountRow.first['c'] as int?) ?? 0;
      if (distinctCount >= 30) {
        return; // Diversidade aceitável
      }
      print('⚠️ Baixa diversidade de livros ($distinctCount). Expandindo dataset...');

      // Livros já presentes
      final existingRows = await gameDb.rawQuery('SELECT DISTINCT book_name FROM verse_quiz_data');
      final existing = existingRows.map((e) => e['book_name'] as String).toSet();

      // Abrir DB da Bíblia de referência
      final bibleDb = await DatabaseHelper().bibleManager.openBibleVersion(referenceVersion);
      final allBooksRows = await bibleDb.rawQuery('SELECT id, name FROM book ORDER BY id');

      // Parâmetros de seleção por livro
      const int perBookTarget = 60; // número de versículos por livro (aprox) a inserir
      const int minLen = 50;
      const int maxLen = 300;

      int inserted = 0;
      final batch = gameDb.batch();

      for (var book in allBooksRows) {
        final bookName = book['name'] as String;
        if (existing.contains(bookName)) continue; // já temos

        // Buscar versos elegíveis aleatórios deste livro
        final verses = await bibleDb.rawQuery('''
          SELECT v.id as verse_id, v.chapter, v.verse as verse_number, LENGTH(v.text) as char_count
          FROM verse v
          JOIN book b ON v.book_id = b.id
          WHERE b.name = ? AND LENGTH(v.text) BETWEEN ? AND ?
          ORDER BY RANDOM()
          LIMIT ?
        ''', [bookName, minLen, maxLen, perBookTarget]);

        if (verses.isEmpty) continue;
        for (var v in verses) {
          batch.insert('verse_quiz_data', {
            'verse_id': v['verse_id'],
            'book_name': bookName,
            'chapter': v['chapter'],
            'verse_number': v['verse_number'],
            'is_quiz_eligible': 1,
            'word_count': ((v['char_count'] as int) / 5).round(),
            'character_count': v['char_count'],
            'usage_count': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        }
      }

      if (inserted > 0) {
        await batch.commit(noResult: true);
        print('✅ Dataset expandido: +$inserted versos adicionados para novos livros.');
      } else {
        print('ℹ️ Nenhum novo verso inserido (talvez todos os livros já estejam presentes ou sem versos elegíveis).');
      }
    } catch (e, st) {
      print('❌ Erro ao expandir diversidade de livros: $e');
      print(st);
    }
  }

  /// Salva resposta do usuário (sem vincular à versão específica - progressão única)
  Future<void> saveUserResponse({
    required int verseId,
    required String bookName,
    required String sessionId,
    required bool correct,
    required String difficulty,
    required List<String> alternatives,
    required int timeToAnswer,
    required int pointsEarned,
    int streakAtTime = 0,
  }) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.insert('user_responses', {
        'verse_id': verseId,
        'book_name': bookName,
        'session_id': sessionId,
        'correct': correct ? 1 : 0,
        'difficulty_chosen': difficulty,
        'alternatives_shown': alternatives.join('|'),
        'time_to_answer': timeToAnswer,
        'points_earned': pointsEarned,
        'streak_at_time': streakAtTime,
      });

      // Atualizar progresso geral do usuário
      await gameDb.rawUpdate('''
        UPDATE user_progress SET 
          total_questions_answered = total_questions_answered + 1,
          total_correct_answers = total_correct_answers + ?,
          total_points = total_points + ?,
          current_streak = ?,
          best_streak = CASE WHEN ? > best_streak THEN ? ELSE best_streak END,
          updated_at = ?
      ''', [correct ? 1 : 0, pointsEarned, streakAtTime, streakAtTime, streakAtTime, DateTime.now().toIso8601String()]);

      print('✅ Resposta salva: versículo $verseId, correct: $correct');
    } catch (e) {
      print('❌ Erro ao salvar resposta: $e');
      throw Exception('Erro ao salvar resposta: $e');
    }
  }

  /// Busca estatísticas do usuário (progressão única)
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      // Buscar progresso geral
      final progressResult = await gameDb.query('user_progress', limit: 1);
      Map<String, dynamic> progress = progressResult.isNotEmpty 
          ? progressResult.first 
          : {
              'total_sessions': 0,
              'total_questions_answered': 0,
              'total_correct_answers': 0,
              'total_points': 0,
              'current_streak': 0,
              'best_streak': 0,
            };
      
      // Buscar estatísticas de hoje
      String today = DateTime.now().toIso8601String().split('T')[0];
      final todayResult = await gameDb.query(
        'daily_stats',
        where: 'date = ?',
        whereArgs: [today],
        limit: 1,
      );
      
      Map<String, dynamic> todayStats = todayResult.isNotEmpty
          ? todayResult.first
          : {
              'sessions_played': 0,
              'total_questions': 0,
              'correct_answers': 0,
              'total_points': 0,
            };
      
      // Versão atual escolhida
      String currentVersion = await BibleSettingsService().getCurrentBibleVersion();
      
      return {
        'progress': progress,
        'today': todayStats,
        'current_bible_version': currentVersion,
      };
      
    } catch (e) {
      print('❌ Erro ao buscar estatísticas: $e');
      return {
        'progress': {},
        'today': {},
        'current_bible_version': 'NVI',
      };
    }
  }

  /// Busca o versículo correto pelo livro, capítulo e número do versículo
  Future<Map<String, dynamic>?> _getCorrectVerse(String version, String bookName, int chapter, int verseNumber) async {
    try {
      final db = await DatabaseHelper().bibleManager.openBibleVersion(version);
      final result = await db.rawQuery('''
        SELECT v.* 
        FROM verse v
        INNER JOIN book b ON v.book_id = b.id
        WHERE b.name = ? AND v.chapter = ? AND v.verse = ?
        LIMIT 1
      ''', [bookName, chapter, verseNumber]);
      
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Erro ao buscar versículo correto: $e');
      return null;
    }
  }

  /// Atualiza o verse_id na tabela quiz_data para corrigir inconsistências
  Future<void> _updateVerseIdInQuizData(int oldVerseId, int newVerseId) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      await gameDb.rawUpdate('''
        UPDATE verse_quiz_data 
        SET verse_id = ?
        WHERE verse_id = ?
      ''', [newVerseId, oldVerseId]);
      
      print('🔧 Corrigido verse_id de $oldVerseId para $newVerseId na tabela');
    } catch (e) {
      print('❌ Erro ao atualizar verse_id: $e');
    }
  }

  /// Incrementa contador de uso de um versículo
  Future<void> _incrementUsageCount(int verseId) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.rawUpdate('''
        UPDATE verse_quiz_data 
        SET usage_count = usage_count + 1,
            last_used_date = ?
        WHERE verse_id = ?
      ''', [DateTime.now().toIso8601String(), verseId]);

    } catch (e) {
      print('⚠️ Erro ao incrementar contador de uso: $e');
    }
  }

  /// Adiciona versículo aos favoritos (salva qual versão foi usada como fonte)
  Future<void> addToFavorites({
    required int verseId,
    required String bookName,
    required int chapter,
    required int verseNumber,
    String? notes,
  }) async {
    try {
      String currentVersion = await BibleSettingsService().getCurrentBibleVersion();
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.insert('user_favorites', {
        'verse_id': verseId,
        'book_name': bookName,
        'chapter': chapter,
        'verse_number': verseNumber,
        'bible_version_source': currentVersion,
        'notes': notes,
      });
      
      print('✅ Versículo $verseId adicionado aos favoritos (fonte: $currentVersion)');
    } catch (e) {
      print('❌ Erro ao adicionar aos favoritos: $e');
      throw Exception('Erro ao adicionar aos favoritos: $e');
    }
  }

  /// Lista versículos favoritos com texto na versão atual
  Future<List<Map<String, dynamic>>> getFavoriteVerses() async {
    try {
      String currentVersion = await BibleSettingsService().getCurrentBibleVersion();
      final gameDb = await DatabaseHelper().gameManager.database;
      
      final favorites = await gameDb.query(
        'user_favorites',
        orderBy: 'added_at DESC',
      );
      
      List<Map<String, dynamic>> favoritesWithText = [];
      for (var favorite in favorites) {
        int verseId = favorite['verse_id'] as int;
        var verseText = await DatabaseHelper().bibleManager.getVerse(currentVersion, verseId);
        
        if (verseText != null) {
          favoritesWithText.add({
            ...favorite,
            'text': verseText['text'],
            'current_version': currentVersion,
          });
        }
      }
      
      return favoritesWithText;
    } catch (e) {
      print('❌ Erro ao buscar favoritos: $e');
      return [];
    }
  }

  /// Incrementa o total de sessões jogadas
  Future<void> incrementSessionCount() async {
    final gameDb = await DatabaseHelper().gameManager.database;
    await gameDb.rawUpdate('''
      UPDATE user_progress SET 
        total_sessions = total_sessions + 1,
        updated_at = ?
    ''', [DateTime.now().toIso8601String()]);
  }
}
