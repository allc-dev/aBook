import 'package:sqflite/sqflite.dart';
import 'bible_database_manager.dart';
import 'game_database_manager.dart';
import 'migration_manager.dart';

/// Callback para reportar progresso da inicialização
typedef InitializationProgressCallback = void Function(String message, double progress);


/// Controlador principal dos bancos de dados - coordena Bíblias e Gamificação
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  BibleDatabaseManager? _bibleManager;
  GameDatabaseManager? _gameManager;
  MigrationManager? _migrationManager;
  
  bool _initialized = false;
  
  /// Inicializa todo o sistema de bancos de dados com feedback de progresso
  Future<void> initialize({InitializationProgressCallback? onProgress}) async {
    if (_initialized) return;
    
    try {
      print('🚀 Inicializando sistema de bancos de dados...');
      onProgress?.call('Iniciando sistema de bancos...', 0.0);
      
      // Instancia os gerenciadores
      _migrationManager = MigrationManager();
      _bibleManager = BibleDatabaseManager();
      _gameManager = GameDatabaseManager();

      // 1. Limpeza única dos dados antigos e cache
      // Executa apenas uma vez por instalação/atualização, nunca mais repete
      onProgress?.call('Limpando dados antigos (atualização)...', 0.1);
      await _migrationManager!.forceCleanOldDataOnce();

      // 2. Instalação das versões da Bíblia (se necessário)
      onProgress?.call('Instalando versões da Bíblia...', 0.4);
      await _bibleManager!.extractAndInstallBibles();

      // 3. Inicialização do banco de gamificação
      onProgress?.call('Configurando sistema de quiz...', 0.7);
      await _gameManager!.database;

      // 4. Finalização
      onProgress?.call('Finalizando configuração...', 0.9);

      // Marca como inicializado
      _initialized = true;
      onProgress?.call('Sistema pronto!', 1.0);
      print('✅ Sistema de bancos inicializado com sucesso!');
        
    } catch (e) {
      onProgress?.call('Erro na inicialização', 0.0);
      print('❌ Erro na inicialização dos bancos: $e');
      rethrow;
    }
  }
  
  /// Obtém o gerenciador de Bíblias
  BibleDatabaseManager get bibleManager {
    if (!_initialized) {
      throw Exception('DatabaseHelper não foi inicializado. Chame initialize() primeiro.');
    }
    return _bibleManager!;
  }
  
  /// Obtém o gerenciador de gamificação
  GameDatabaseManager get gameManager {
    if (!_initialized) {
      throw Exception('DatabaseHelper não foi inicializado. Chame initialize() primeiro.');
    }
    return _gameManager!;
  }
  
  /// Obtém o gerenciador de migração
  MigrationManager get migrationManager {
    if (!_initialized) {
      throw Exception('DatabaseHelper não foi inicializado. Chame initialize() primeiro.');
    }
    return _migrationManager!;
  }
  
  /// [DEPRECATED] Mantido para compatibilidade - use gameManager.database
  @deprecated
  Future<Database> get database async {
    if (!_initialized) {
      await initialize();
    }
    return await _gameManager!.database;
  }
  
  /// Fecha todos os bancos de dados
  Future<void> close() async {
    if (_bibleManager != null) {
      await _bibleManager!.closeAll();
    }
    if (_gameManager != null) {
      await _gameManager!.close();
    }
    _initialized = false;
  }
}
