import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'bible_database_manager.dart';

/// Gerencia o banco de dados de gamificação (separado das Bíblias)
class GameDatabaseManager {
  static final GameDatabaseManager _instance = GameDatabaseManager._internal();
  factory GameDatabaseManager() => _instance;
  GameDatabaseManager._internal();
  
  Database? _database;
  static const int DATABASE_VERSION = 1;
  static const String DATABASE_NAME = 'game_data.db';
  
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    try {
      print('🎮 Inicializando banco de gamificação...');
      
      String databasesPath = await getDatabasesPath();
      String path = join(databasesPath, DATABASE_NAME);
      
      return await openDatabase(
        path,
        version: DATABASE_VERSION,
        onCreate: _createGameTables,
        onUpgrade: _upgradeDatabase,
      );
    } catch (e) {
      print('❌ Erro ao inicializar banco de gamificação: $e');
      rethrow;
    }
  }
  
  /// Cria todas as tabelas de gamificação
  Future<void> _createGameTables(Database db, int version) async {
    print('🎮 Criando tabelas de gamificação...');
    
    // Configurações do usuário
    await db.execute('''CREATE TABLE user_settings (
      id INTEGER PRIMARY KEY,
      current_bible_version TEXT DEFAULT 'NVI',
      daily_goal INTEGER DEFAULT 10,
      notifications_enabled BOOLEAN DEFAULT 1,
      sound_enabled BOOLEAN DEFAULT 1,
      vibration_enabled BOOLEAN DEFAULT 1,
      theme TEXT DEFAULT 'light',
      font_size INTEGER DEFAULT 16,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )''');
    
    // Tabela de histórico de leitura
    await db.execute('''CREATE TABLE IF NOT EXISTS reading_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_name TEXT,
      chapter INTEGER,
      bible_version TEXT,
      read_date TEXT,
      points_earned INTEGER
    )''');
    
    // Classificação de dificuldade dos livros (independente da versão)
    await db.execute('''CREATE TABLE book_difficulty (
      id INTEGER PRIMARY KEY,
      book_name TEXT UNIQUE,
      difficulty_level TEXT CHECK(difficulty_level IN ('fácil', 'médio', 'difícil')),
      points_value INTEGER,
      testament_type TEXT CHECK(testament_type IN ('AT', 'NT')),
      popularity_score INTEGER CHECK(popularity_score BETWEEN 1 AND 10)
    )''');
    
    // Controle de versículos para quiz (progressão única)
    await db.execute('''CREATE TABLE verse_quiz_data (
      id INTEGER PRIMARY KEY,
      verse_id INTEGER UNIQUE,
      book_name TEXT,
      chapter INTEGER,
      verse_number INTEGER,
      is_quiz_eligible BOOLEAN DEFAULT 1,
      word_count INTEGER,
      character_count INTEGER,
      last_used_date TEXT,
      usage_count INTEGER DEFAULT 0,
      blacklist_reason TEXT,
      difficulty_override TEXT
    )''');
    
    // Black list de frases comuns
    await db.execute('''CREATE TABLE verse_blacklist_phrases (
      id INTEGER PRIMARY KEY,
      phrase TEXT UNIQUE,
      reason TEXT,
      testament_type TEXT
    )''');
    
    // Respostas do usuário (progressão única)
    await db.execute('''CREATE TABLE user_responses (
      id INTEGER PRIMARY KEY,
      verse_id INTEGER,
      book_name TEXT,
      session_id TEXT,
      date_answered DATETIME DEFAULT CURRENT_TIMESTAMP,
      correct BOOLEAN,
      difficulty_chosen TEXT,
      alternatives_shown TEXT,
      time_to_answer INTEGER,
      points_earned INTEGER,
      streak_at_time INTEGER DEFAULT 0
    )''');
    
    // Sessões de jogo (progressão única)
    await db.execute('''CREATE TABLE game_sessions (
      id TEXT PRIMARY KEY,
      start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
      end_time DATETIME,
      difficulty_level TEXT,
      total_questions INTEGER DEFAULT 0,
      correct_answers INTEGER DEFAULT 0,
      wrong_answers INTEGER DEFAULT 0,
      total_points INTEGER DEFAULT 0,
      session_completed BOOLEAN DEFAULT 0,
      best_streak INTEGER DEFAULT 0,
      books_played TEXT
    )''');
    
    // Estatísticas diárias (progressão única)
    await db.execute('''CREATE TABLE daily_stats (
      id INTEGER PRIMARY KEY,
      date TEXT UNIQUE,
      sessions_played INTEGER DEFAULT 0,
      total_questions INTEGER DEFAULT 0,
      correct_answers INTEGER DEFAULT 0,
      total_points INTEGER DEFAULT 0,
      best_session_points INTEGER DEFAULT 0,
      easy_correct INTEGER DEFAULT 0,
      medium_correct INTEGER DEFAULT 0,
      hard_correct INTEGER DEFAULT 0
    )''');
    
    // Sistema de conquistas
    await db.execute('''CREATE TABLE achievements (
      id INTEGER PRIMARY KEY,
      name TEXT UNIQUE,
      description TEXT,
      icon TEXT,
      unlock_condition TEXT,
      unlocked_at DATETIME,
      is_unlocked BOOLEAN DEFAULT 0
    )''');
    
    // Progresso geral do usuário (único)
    await db.execute('''CREATE TABLE user_progress (
      id INTEGER PRIMARY KEY,
      total_sessions INTEGER DEFAULT 0,
      total_questions_answered INTEGER DEFAULT 0,
      total_correct_answers INTEGER DEFAULT 0,
      total_points INTEGER DEFAULT 0,
      current_streak INTEGER DEFAULT 0,
      best_streak INTEGER DEFAULT 0,
      favorite_book TEXT,
      mastery_level TEXT DEFAULT 'iniciante',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )''');
    
    // Favoritos do usuário (único, mas salva de qual versão veio)
    await db.execute('''CREATE TABLE user_favorites (
      id INTEGER PRIMARY KEY,
      verse_id INTEGER,
      book_name TEXT,
      chapter INTEGER,
      verse_number INTEGER,
      bible_version_source TEXT,
      added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      notes TEXT,
      UNIQUE(verse_id)
    )''');
    
    // Popular dados iniciais
    await _populateInitialGameData(db);
    
    print('✅ Tabelas de gamificação criadas com sucesso!');
  }
  
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    print('🔄 Atualizando banco de gamificação v$oldVersion → v$newVersion...');
    // Implementar futuras atualizações aqui
  }
  
  /// Popular dados iniciais do jogo (conquistas, dificuldades, blacklist)
  Future<void> _populateInitialGameData(Database db) async {
    print('🌱 Populando dados iniciais de gamificação...');
    
    // Inserir configuração padrão do usuário
    await db.insert('user_settings', {
      'current_bible_version': 'NVI',
      'daily_goal': 10,
      'notifications_enabled': 1,
      'sound_enabled': 1,
      'vibration_enabled': 1,
      'theme': 'light',
      'font_size': 16,
    });
    
    // Inserir progresso inicial
    await db.insert('user_progress', {
      'total_sessions': 0,
      'total_questions_answered': 0,
      'total_correct_answers': 0,
      'total_points': 0,
      'current_streak': 0,
      'best_streak': 0,
      'mastery_level': 'iniciante',
    });
    
    Batch batch = db.batch();
    
    // Classificação de dificuldade dos livros
    final List<Map<String, dynamic>> bookDifficulties = [
      // FÁCIL - Livros mais conhecidos
      {'book_name': 'Salmos', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'AT', 'popularity_score': 10},
      {'book_name': 'Provérbios', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'AT', 'popularity_score': 9},
      {'book_name': 'Gênesis', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'AT', 'popularity_score': 10},
      {'book_name': 'Êxodo', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'AT', 'popularity_score': 9},
      {'book_name': 'Mateus', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'NT', 'popularity_score': 10},
      {'book_name': 'João', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'NT', 'popularity_score': 10},
      {'book_name': 'Romanos', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'NT', 'popularity_score': 9},
      {'book_name': '1 Coríntios', 'difficulty_level': 'fácil', 'points_value': 10, 'testament_type': 'NT', 'popularity_score': 8},
      
      // MÉDIO - Livros conhecidos mas menos populares
      {'book_name': 'Números', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'AT', 'popularity_score': 3},
      {'book_name': 'Juízes', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'AT', 'popularity_score': 6},
      {'book_name': 'Jó', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'AT', 'popularity_score': 7},
      {'book_name': 'Isaías', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'AT', 'popularity_score': 8},
      {'book_name': 'Marcos', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'NT', 'popularity_score': 8},
      {'book_name': 'Lucas', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'NT', 'popularity_score': 9},
      {'book_name': 'Atos', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'NT', 'popularity_score': 8},
      {'book_name': 'Hebreus', 'difficulty_level': 'médio', 'points_value': 15, 'testament_type': 'NT', 'popularity_score': 7},
      
      // DIFÍCIL - Livros menos conhecidos
      {'book_name': 'Levítico', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'AT', 'popularity_score': 2},
      {'book_name': 'Obadias', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'AT', 'popularity_score': 1},
      {'book_name': 'Naum', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'AT', 'popularity_score': 1},
      {'book_name': 'Filemom', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'NT', 'popularity_score': 2},
      {'book_name': '2 João', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'NT', 'popularity_score': 1},
      {'book_name': '3 João', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'NT', 'popularity_score': 1},
      {'book_name': 'Judas', 'difficulty_level': 'difícil', 'points_value': 20, 'testament_type': 'NT', 'popularity_score': 2},
    ];
    
    for (var book in bookDifficulties) {
      batch.insert('book_difficulty', book);
    }
    
    // Blacklist de frases comuns
    final List<Map<String, dynamic>> blacklistPhrases = [
      {'phrase': 'então disse o senhor', 'reason': 'Frase genérica repetida', 'testament_type': 'AT'},
      {'phrase': 'assim diz o senhor', 'reason': 'Frase profética genérica', 'testament_type': 'AT'},
      {'phrase': 'palavra do senhor', 'reason': 'Frase genérica', 'testament_type': 'BOTH'},
      {'phrase': 'jesus disse', 'reason': 'Muito genérico', 'testament_type': 'NT'},
      {'phrase': 'respondeu jesus', 'reason': 'Muito comum', 'testament_type': 'NT'},
      {'phrase': 'disse-lhes jesus', 'reason': 'Estrutura comum', 'testament_type': 'NT'},
    ];
    
    for (var phrase in blacklistPhrases) {
      batch.insert('verse_blacklist_phrases', phrase);
    }
    
    // Conquistas iniciais
    final List<Map<String, dynamic>> achievements = [
      {'name': 'Primeiro Passo', 'description': 'Complete sua primeira sessão', 'icon': 'first_step', 'unlock_condition': '{"sessions_completed": 1}'},
      {'name': 'Explorador', 'description': 'Use 3 versões diferentes da Bíblia', 'icon': 'explorer', 'unlock_condition': '{"bible_versions_used": 3}'},
      {'name': 'Conhecedor', 'description': 'Acerte 50 perguntas', 'icon': 'knowledgeable', 'unlock_condition': '{"total_correct": 50}'},
      {'name': 'Mestre dos Salmos', 'description': 'Acerte 20 versículos de Salmos', 'icon': 'psalms_master', 'unlock_condition': '{"book_correct": {"Salmos": 20}}'},
      {'name': 'Perfeccionista', 'description': 'Complete uma sessão sem erros', 'icon': 'perfectionist', 'unlock_condition': '{"perfect_session": 1}'},
      {'name': 'Desbravador', 'description': 'Acerte versículos em todas as dificuldades', 'icon': 'pioneer', 'unlock_condition': '{"all_difficulties": 1}'},
      {'name': 'Colecionador', 'description': 'Adicione 10 versículos aos favoritos', 'icon': 'collector', 'unlock_condition': '{"favorites_added": 10}'},
    ];
    
    for (var achievement in achievements) {
      batch.insert('achievements', achievement);
    }
    
    await batch.commit();
    print('✅ Dados iniciais de gamificação populados!');
    
    // Popular tabela verse_quiz_data com versículos das Bíblias
    await _populateVerseQuizData(db);
  }

  /// Popula a tabela verse_quiz_data com versículos de todas as Bíblias (otimizado)
  Future<void> _populateVerseQuizData(Database db) async {
    print('📚 Populando dados de versículos para quiz...');
    
    try {
      // Verificar se já tem dados
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM verse_quiz_data')
      ) ?? 0;
      
      if (count > 0) {
        print('ℹ️ Dados de versículos já populados ($count registros)');
        return;
      }
      
      // Usar uma versão como referência (NVI) para obter os versículos
      final bibleManager = BibleDatabaseManager();
      
      // Verificar se a versão NVI está disponível antes de abrir
      if (!await bibleManager.isVersionAvailable('NVI')) {
        print('⚠️ Versão NVI não disponível, pulando população de versículos');
        return;
      }
      
      final nviDb = await bibleManager.openBibleVersion('NVI');
      
      // Buscar versículos elegíveis (otimizado: tamanho entre 30 e 200 caracteres, limite 3000)
      print('🔍 Buscando versículos elegíveis...');
      final verses = await nviDb.rawQuery('''
        SELECT v.id, v.chapter, v.verse, b.name as book_name, LENGTH(v.text) as char_count
        FROM verse v
        JOIN book b ON v.book_id = b.id
        WHERE LENGTH(v.text) BETWEEN 50 AND 300
        ORDER BY v.id
        LIMIT 5000
      ''');
      
      print('📊 Encontrados ${verses.length} versículos elegíveis');
      
      if (verses.isEmpty) {
        print('⚠️ Nenhum versículo encontrado para o quiz');
        return;
      }
      
      // Inserir em batches maiores para ser mais rápido
      Batch batch = db.batch();
      int batchCount = 0;
      int processed = 0;
      
      for (var verse in verses) {
        final charCount = verse['char_count'] as int;
        final wordCount = (charCount / 6).round();
        
        try {
          batch.insert('verse_quiz_data', {
            'verse_id': verse['id'],
            'book_name': verse['book_name'],
            'chapter': verse['chapter'],
            'verse_number': verse['verse'],
            'is_quiz_eligible': 1,
            'word_count': wordCount,
            'character_count': charCount,
            'usage_count': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        } catch (e) {
          print('❌ Erro ao inserir versículo no batch: $e');
          print('Dados: id=${verse['id']}, book_name=${verse['book_name']}, chapter=${verse['chapter']}, verse=${verse['verse']}');
        }
        
        batchCount++;
        processed++;
        
        // Executar em batches maiores (500 por vez)
        if (batchCount >= 500) {
          await batch.commit(noResult: true);
          batch = db.batch();
          batchCount = 0;
          print('📝 Processados $processed/${verses.length} versículos...');
        }
      }
      
      // Executar batch restante
      if (batchCount > 0) {
        await batch.commit(noResult: true);
      }
      
      print('✅ ${verses.length} versículos populados na tabela verse_quiz_data!');
      
    } catch (e) {
      print('❌ Erro ao popular verse_quiz_data: $e');
      // Não rethrow para não quebrar a inicialização
    }
  }
  
  /// Fecha o banco de gamificação
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
