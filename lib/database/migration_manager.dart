// ignore_for_file: constant_identifier_names

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Gerencia apenas a limpeza física dos bancos antigos, backups e cache.
/// Não realiza nenhuma migração ou cópia de dados entre bancos.
class MigrationManager {
  static final MigrationManager _instance = MigrationManager._internal();
  factory MigrationManager() => _instance;
  MigrationManager._internal();
  
  static const String OLD_DATABASE_NAME = 'bible_quiz.db';
  static const String MIGRATION_FLAG_FILE = 'migration_completed.flag';
  
  
  /// Limpa dados antigos (banco, backup, cache) apenas uma vez por instalação/atualização.
  /// Não faz migração ou cópia de dados.
  static const String UPDATE_CLEANUP_FLAG = 'update_2025_cleanup.flag';

  Future<void> forceCleanOldDataOnce() async {
    try {
      String databasesPath = await getDatabasesPath();
      String flagPath = join(databasesPath, UPDATE_CLEANUP_FLAG);

      if (await File(flagPath).exists()) {
        print('🟢 Limpeza já foi feita na atualização, não será repetida.');
        return;
      }

      print('🧹 Executando limpeza de dados antigos e cache para atualização única...');

      // Remover banco antigo se existir
      String oldPath = join(databasesPath, OLD_DATABASE_NAME);
      if (await File(oldPath).exists()) {
        await File(oldPath).delete();
        print('🗑️ Banco antigo removido: $OLD_DATABASE_NAME');
      }

      // Remover flag de migração para forçar recriação
      String migrationFlagPath = join(databasesPath, MIGRATION_FLAG_FILE);
      if (await File(migrationFlagPath).exists()) {
        await File(migrationFlagPath).delete();
        print('🗑️ Flag de migração removida');
      }

      // Remover backup antigo se existir
      String backupPath = join(databasesPath, '$OLD_DATABASE_NAME.backup');
      if (await File(backupPath).exists()) {
        await File(backupPath).delete();
        print('🗑️ Backup antigo removido');
      }

      // Limpar SharedPreferences (cache store)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('🧹 SharedPreferences limpo!');
      } catch (e) {
        print('⚠️ Erro ao limpar SharedPreferences: $e');
      }

      // Criar flag para nunca mais repetir
      await File(flagPath).writeAsString('cleanup_done');
      print('✅ Limpeza de dados antigos e cache concluída e flag criada!');

    } catch (e) {
      print('⚠️ Erro na limpeza de dados antigos/cache: $e');
      // Não rethrow para não quebrar a inicialização
    }
  }

  /// Remove arquivos de migração e backup (para limpeza)
  Future<void> cleanup() async {
    try {
      String databasesPath = await getDatabasesPath();
      
      // Remover backup antigo se existir
      String backupPath = join(databasesPath, '$OLD_DATABASE_NAME.backup');
      if (await File(backupPath).exists()) {
        await File(backupPath).delete();
        print('✅ Backup antigo removido');
      }
      
    } catch (e) {
      print('⚠️ Erro na limpeza: $e');
    }
  }
}
