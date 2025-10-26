import 'dart:math';
import '../models/question_model.dart';
import '../models/verse_model.dart';
import '../database/bible_repository.dart';
import '../services/verse_quiz_service.dart';

class QuestionGeneratorService {
  final BibleRepository _repository = BibleRepository();
  final VerseQuizService _verseQuizService = VerseQuizService();
  final Random _random = Random();

  /// Gera múltiplas perguntas usando o novo sistema de versões múltiplas
  Future<List<QuestionModel>> generateQuestions(String difficulty, {int count = 10}) async {
    print('🎮 Gerando $count perguntas para dificuldade: $difficulty via novo sistema');
    
    try {
      // Usar o novo serviço para buscar versículos na versão atual do usuário
      final versesData = await _verseQuizService.getQuizVerses(difficulty, limit: count);
      
      if (versesData.isEmpty) {
        print('❌ Nenhum versículo encontrado para gerar perguntas');
        return [];
      }
      
      List<QuestionModel> questions = [];
      int successCount = 0;
      
      for (var verseData in versesData) {
        if (successCount >= count) break;
        
        // Debug: verificar se os dados do versículo estão corretos
        print('🔍 Debug dados do versículo: ${verseData}');
        
        // Verificar se os campos necessários não são nulos ou zero
        final verseId = verseData['verse_id'];
        final chapter = verseData['chapter'];
        final verseNumber = verseData['verse_number']; 
        final bookName = verseData['book_name'];
        final text = verseData['text'];
        
        if (verseId == null || chapter == null || verseNumber == null || bookName == null || text == null) {
          print('❌ Dados do versículo incompletos: verse_id=$verseId, chapter=$chapter, verse_number=$verseNumber, book_name=$bookName, text_length=${text?.toString().length}');
          continue;
        }
        
        if (chapter == 0 || verseNumber == 0) {
          print('❌ Versículo com valores zerados: $bookName $chapter:$verseNumber');
          continue;
        }
        
        final verse = VerseModel(
          id: verseId,
          bookId: verseData['book_id'] ?? 0,
          chapter: chapter,
          verse: verseNumber,
          text: text,
          bookName: bookName,
          difficultyLevel: difficulty,
          pointsValue: verseData['points_value'] ?? _getDefaultPoints(difficulty),
        );
        
        print('✅ VerseModel criado: ${verse.bookName} ${verse.chapter}:${verse.verse}');
        
        final question = await generateQuestionFromVerse(verse, difficulty);
        if (question != null) {
          questions.add(question);
          successCount++;
          print('✅ Pergunta ${successCount}/$count: ${verse.bookName} - ${verse.chapter}:${verse.verse} (${verseData['bible_version'] ?? 'versão atual'})');
        } else {
          print('⚠️ Falha ao gerar pergunta para: ${verse.bookName} - ${verse.chapter}:${verse.verse}');
        }
      }
      
      print('🏁 Total de perguntas geradas: ${questions.length}/$count');
      
      if (questions.length < count) {
        print('⚠️ Só foi possível gerar ${questions.length} de $count perguntas');
      }

      // Embaralhar a ordem final das perguntas
      questions.shuffle(_random);

      return questions;
    } catch (e) {
      print('❌ Erro ao gerar perguntas: $e');
      return [];
    }
  }

  /// Gera uma nova pergunta baseada na dificuldade escolhida (usando um versículo já fornecido)
  Future<QuestionModel?> generateQuestionFromVerse(VerseModel verse, String difficulty) async {
    try {
      // 1. Determinar o testamento do livro
      final testament = await _repository.getTestamentByBookName(verse.bookName ?? '');
      if (testament == null) {
        print('❌ Testamento não encontrado para: ${verse.bookName}');
        return null;
      }

      // 2. Gerar alternativas do mesmo testamento
      final alternatives = await _repository.generateAlternatives(
        verse.bookName ?? '',
        testament,
      );

      if (alternatives.length < 3) {
        print('❌ Não foi possível gerar 3 alternativas para: ${verse.bookName}');
        return null;
      }

      // 3. Calcular pontos baseado na dificuldade escolhida (não no versículo)
      final points = _getDefaultPoints(difficulty);

      // 4. Criar a pergunta
      final question = QuestionModel(
        verse: verse,
        alternatives: alternatives,
        correctAnswer: verse.bookName ?? '',
        difficulty: difficulty,
        pointsValue: points,
      );

      print('✅ Pergunta gerada: ${verse.bookName} (dificuldade: ${difficulty}) - ${points} pontos');
      return question;

    } catch (e) {
      print('❌ Erro ao gerar pergunta: $e');
      return null;
    }
  }

  /// Retorna pontos baseado na dificuldade escolhida
  int _getDefaultPoints(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'fácil':
        return 10;
      case 'médio':
        return 15;
      case 'difícil':
        return 20;
      default:
        print('⚠️ Dificuldade desconhecida: $difficulty, usando pontos padrão (15)');
        return 15;
    }
  }

  /// Embaralha as alternativas de uma pergunta
  List<String> shuffleAlternatives(QuestionModel question) {
    final allOptions = [question.correctAnswer, ...question.alternatives];
    allOptions.shuffle(_random);
    return allOptions;
  }

  /// Verifica quantas perguntas podem ser geradas para uma dificuldade
  Future<int> getAvailableQuestionsCount(String difficulty) async {
    try {
      // Usar novo sistema para contar perguntas disponíveis
      final versesData = await _verseQuizService.getQuizVerses(difficulty, limit: 100);
      return versesData.length;
    } catch (e) {
      print('❌ Erro ao contar perguntas disponíveis: $e');
      return 0;
    }
  }

  /// Limpa cache de perguntas usadas recentemente (se necessário)
  Future<void> clearRecentQuestionsCache() async {
    try {
      // No novo sistema, isso é gerenciado pelo VerseQuizService
      print('🧹 Cache de perguntas gerenciado automaticamente pelo novo sistema');
    } catch (e) {
      print('❌ Erro ao limpar cache: $e');
    }
  }
}
