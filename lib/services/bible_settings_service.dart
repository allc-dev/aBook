import '../database/database_helper.dart';
import '../database/bible_database_manager.dart';

/// Service para gerenciar configurações da versão da Bíblia
class BibleSettingsService {
  static final BibleSettingsService _instance = BibleSettingsService._internal();
  factory BibleSettingsService() => _instance;
  BibleSettingsService._internal();

  /// Obtém a versão atual da Bíblia escolhida pelo usuário
  Future<String> getCurrentBibleVersion() async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      final result = await gameDb.query(
        'user_settings',
        columns: ['current_bible_version'],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return result.first['current_bible_version'] as String? ?? 'NVI';
      }
      
      return 'NVI'; // Padrão
    } catch (e) {
      print('Erro ao obter versão da Bíblia: $e');
      return 'NVI';
    }
  }

  /// Define a nova versão da Bíblia escolhida pelo usuário
  Future<void> setBibleVersion(String version) async {
    try {
      final gameDb = await DatabaseHelper().gameManager.database;
      
      await gameDb.update(
        'user_settings',
        {
          'current_bible_version': version,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
      
      print('✅ Versão da Bíblia alterada para: $version');
    } catch (e) {
      print('❌ Erro ao alterar versão da Bíblia: $e');
      throw Exception('Erro ao alterar versão da Bíblia: $e');
    }
  }

  /// Verifica se uma versão específica está disponível
  Future<bool> isVersionAvailable(String version) async {
    try {
      return await DatabaseHelper().bibleManager.isVersionAvailable(version);
    } catch (e) {
      print('Erro ao verificar disponibilidade da versão $version: $e');
      return false;
    }
  }

  /// Lista todas as versões disponíveis
  List<Map<String, String>> getAvailableVersions() {
    return BibleDatabaseManager.AVAILABLE_VERSIONS;
  }
}
