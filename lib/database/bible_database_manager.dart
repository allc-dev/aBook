import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';

/// Gerencia os bancos das diferentes versões da Bíblia
class BibleDatabaseManager {
  static final BibleDatabaseManager _instance = BibleDatabaseManager._internal();
  factory BibleDatabaseManager() => _instance;
  BibleDatabaseManager._internal();

  final Map<String, Database> _bibleDatabases = {};
  
  /// Versões disponíveis da Bíblia
  static const List<Map<String, String>> AVAILABLE_VERSIONS = [
    {'code': 'ACF', 'name': 'Almeida Corrigida Fiel', 'file': 'ACF.sqlite'},
    {'code': 'ARC', 'name': 'Almeida Revista e Corrigida', 'file': 'ARC.sqlite'},
    {'code': 'JFAA', 'name': 'João Ferreira de Almeida Atualizada', 'file': 'JFAA.sqlite'},
    {'code': 'NAA', 'name': 'Nova Almeida Atualizada', 'file': 'NAA.sqlite'},
    {'code': 'NTLH', 'name': 'Nova Tradução na Linguagem de Hoje', 'file': 'NTLH.sqlite'},
    {'code': 'NVI', 'name': 'Nova Versão Internacional', 'file': 'NVI.sqlite'},
    {'code': 'NVT', 'name': 'Nova Versão Transformadora', 'file': 'NVT.sqlite'},
    {'code': 'TB', 'name': 'Tradução Brasileira', 'file': 'TB.sqlite'},
  ];
  
  /// Extrai e instala todas as versões da Bíblia do arquivo biblias.zip (otimizado)
  Future<void> extractAndInstallBibles() async {
    try {
      print('📚 Verificando versões da Bíblia...');
      
      String databasesPath = await getDatabasesPath();
      String biblesDir = join(databasesPath, 'bibles');
      
      // Criar diretório das bíblias se não existir
      await Directory(biblesDir).create(recursive: true);
      
      // Verificar se já foram extraídas
      bool allInstalled = true;
      List<String> missingVersions = [];
      
      for (var version in AVAILABLE_VERSIONS) {
        String biblePath = join(biblesDir, version['file']!);
        if (!await File(biblePath).exists()) {
          allInstalled = false;
          missingVersions.add(version['name']!);
        }
      }
      
      if (allInstalled) {
        print('✅ Todas as ${AVAILABLE_VERSIONS.length} versões da Bíblia já estão instaladas');
        return;
      }
      
      print('📥 Extraindo ${missingVersions.length} versões da Bíblia...');
      
      // Carregar arquivo zip dos assets
      ByteData zipData = await rootBundle.load('assets/biblias.zip');
      Uint8List zipBytes = zipData.buffer.asUint8List();
      
      // Extrair arquivo zip
      Archive archive = ZipDecoder().decodeBytes(zipBytes);
      
      int extractedCount = 0;
      for (ArchiveFile file in archive) {
        if (file.name.endsWith('.sqlite')) {
          String fileName = basename(file.name);
          String filePath = join(biblesDir, fileName);
          
          // Só extrair se não existir
          if (!await File(filePath).exists()) {
            // Escrever arquivo extraído
            await File(filePath).writeAsBytes(file.content as List<int>);
            extractedCount++;
            print('📖 Extraído: $fileName');
          }
        }
      }
      
      if (extractedCount > 0) {
        print('✅ $extractedCount versões da Bíblia extraídas com sucesso!');
      } else {
        print('ℹ️ Todas as versões já estavam extraídas');
      }
      
    } catch (e) {
      print('❌ Erro ao extrair versões da Bíblia: $e');
      throw Exception('Falha na instalação das versões da Bíblia: $e');
    }
  }
  
  /// Abre uma versão específica da Bíblia
  Future<Database> openBibleVersion(String versionCode) async {
    if (_bibleDatabases.containsKey(versionCode)) {
      return _bibleDatabases[versionCode]!;
    }
    
    // Encontrar dados da versão
    var versionData = AVAILABLE_VERSIONS.firstWhere(
      (v) => v['code'] == versionCode,
      orElse: () => throw Exception('Versão da Bíblia não encontrada: $versionCode'),
    );
    
    String databasesPath = await getDatabasesPath();
    String biblePath = join(databasesPath, 'bibles', versionData['file']!);
    
    if (!await File(biblePath).exists()) {
      throw Exception('Arquivo da Bíblia não encontrado: ${versionData['file']}');
    }
    
    Database db = await openDatabase(
      biblePath,
      readOnly: true,
    );
    
    _bibleDatabases[versionCode] = db;
    print('📖 Versão da Bíblia aberta: ${versionData['name']}');
    
    return db;
  }
  
  /// Busca um versículo específico
  Future<Map<String, dynamic>?> getVerse(String versionCode, int verseId) async {
    Database db = await openBibleVersion(versionCode);
    
    List<Map<String, dynamic>> result = await db.query(
      'verse',
      where: 'id = ?',
      whereArgs: [verseId],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }
  
  /// Busca versículos de um livro específico
  Future<List<Map<String, dynamic>>> getBookVerses(String versionCode, String bookName) async {
    Database db = await openBibleVersion(versionCode);
    
    // Assumindo que existe uma tabela 'book' com relacionamento
    return await db.rawQuery('''
      SELECT v.* 
      FROM verse v
      INNER JOIN chapter c ON v.chapter_id = c.id
      INNER JOIN book b ON c.book_id = b.id
      WHERE b.name = ?
      ORDER BY c.chapter_number, v.verse_number
    ''', [bookName]);
  }
  
  /// Lista todos os livros de uma versão
  Future<List<Map<String, dynamic>>> getBooks(String versionCode) async {
    Database db = await openBibleVersion(versionCode);
    return await db.query('book', orderBy: 'id');
  }
  
  /// Fecha uma versão específica da Bíblia
  Future<void> closeBibleVersion(String versionCode) async {
    if (_bibleDatabases.containsKey(versionCode)) {
      await _bibleDatabases[versionCode]!.close();
      _bibleDatabases.remove(versionCode);
      print('📚 Versão da Bíblia fechada: $versionCode');
    }
  }
  
  /// Fecha todas as versões abertas
  Future<void> closeAll() async {
    for (String versionCode in _bibleDatabases.keys.toList()) {
      await closeBibleVersion(versionCode);
    }
  }
  
  /// Verifica se uma versão específica está disponível
  Future<bool> isVersionAvailable(String versionCode) async {
    try {
      var versionData = AVAILABLE_VERSIONS.firstWhere(
        (v) => v['code'] == versionCode,
        orElse: () => throw Exception('Versão não encontrada'),
      );
      
      String databasesPath = await getDatabasesPath();
      String biblePath = join(databasesPath, 'bibles', versionData['file']!);
      
      return await File(biblePath).exists();
    } catch (e) {
      return false;
    }
  }
}
