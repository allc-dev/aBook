/// Modelo para estatísticas de leitura gamificadas
class ReadingStatsModel {
  final int totalDaysReading;           // Quantos dias diferentes o usuário leu
  final int currentStreak;              // Dias consecutivos atuais
  final int longestStreak;              // Maior sequência de dias consecutivos
  final int totalChaptersRead;          // Total de capítulos lidos
  final int totalBooksStarted;          // Quantos livros diferentes foram lidos (pelo menos 1 capítulo)
  final int totalBooksCompleted;        // Quantos livros foram lidos completamente (todos os capítulos)
  final int totalPointsFromReading;     // Total de pontos ganhos pela leitura
  final DateTime? lastReadingDate;      // Último dia de leitura
  final Map<String, int> bookProgress; // Progresso por livro (capítulos lidos de cada)
  final List<String> favoriteBooks;    // Livros mais lidos (top 5)
  final Map<String, int> readingByMonth; // Leituras por mês (últimos 6 meses)

  ReadingStatsModel({
    this.totalDaysReading = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalChaptersRead = 0,
    this.totalBooksStarted = 0,
    this.totalBooksCompleted = 0,
    this.totalPointsFromReading = 0,
    this.lastReadingDate,
    this.bookProgress = const {},
    this.favoriteBooks = const [],
    this.readingByMonth = const {},
  });

  /// Calcula o nível de leitor baseado nos capítulos lidos
  String get readerLevel {
    if (totalChaptersRead == 0) return 'Iniciante';
    if (totalChaptersRead < 10) return 'Leitor Iniciante';
    if (totalChaptersRead < 50) return 'Leitor Regular';
    if (totalChaptersRead < 100) return 'Leitor Assíduo';
    if (totalChaptersRead < 200) return 'Leitor Experiente';
    if (totalChaptersRead < 365) return 'Leitor Dedicado';
    if (totalChaptersRead < 500) return 'Leitor Veterano';
    if (totalChaptersRead < 750) return 'Estudioso da Palavra';
    if (totalChaptersRead >= 1000) return 'Mestre das Escrituras';
    return 'Grande Leitor';
  }

  /// Retorna um emoji baseado no nível atual
  String get levelEmoji {
    switch (readerLevel) {
      case 'Iniciante':
        return '🌱';
      case 'Leitor Iniciante':
        return '📖';
      case 'Leitor Regular':
        return '📚';
      case 'Leitor Assíduo':
        return '⭐';
      case 'Leitor Experiente':
        return '🏆';
      case 'Leitor Dedicado':
        return '💎';
      case 'Leitor Veterano':
        return '👑';
      case 'Estudioso da Palavra':
        return '🔥';
      case 'Mestre das Escrituras':
        return '✨';
      default:
        return '📖';
    }
  }

  /// Calcula quantos capítulos faltam para o próximo nível
  int get chaptersToNextLevel {
    final current = totalChaptersRead;
    if (current < 10) return 10 - current;
    if (current < 50) return 50 - current;
    if (current < 100) return 100 - current;
    if (current < 200) return 200 - current;
    if (current < 365) return 365 - current;
    if (current < 500) return 500 - current;
    if (current < 750) return 750 - current;
    if (current < 1000) return 1000 - current;
    return 0; // Já no nível máximo
  }

  /// Progresso percentual para o próximo nível (0.0 a 1.0)
  double get progressToNextLevel {
    final current = totalChaptersRead;
    if (current < 10) return current / 10.0;
    if (current < 50) return (current - 10) / 40.0;
    if (current < 100) return (current - 50) / 50.0;
    if (current < 200) return (current - 100) / 100.0;
    if (current < 365) return (current - 200) / 165.0;
    if (current < 500) return (current - 365) / 135.0;
    if (current < 750) return (current - 500) / 250.0;
    if (current < 1000) return (current - 750) / 250.0;
    return 1.0; // Nível máximo
  }

  /// Média de capítulos lidos por dia de leitura
  double get averageChaptersPerDay {
    if (totalDaysReading == 0) return 0.0;
    return totalChaptersRead / totalDaysReading;
  }

  /// Porcentagem de livros da Bíblia já iniciados (66 livros total)
  double get bibleCompletionPercentage {
    return (totalBooksStarted / 66.0).clamp(0.0, 1.0);
  }

  /// Dias desde a última leitura
  int get daysSinceLastReading {
    if (lastReadingDate == null) return -1;
    return DateTime.now().difference(lastReadingDate!).inDays;
  }

  /// Verifica se o usuário leu hoje
  bool get readToday {
    if (lastReadingDate == null) return false;
    final today = DateTime.now();
    final lastRead = lastReadingDate!;
    return today.year == lastRead.year &&
           today.month == lastRead.month &&
           today.day == lastRead.day;
  }

  /// Retorna uma mensagem motivacional baseada nas estatísticas
  String get motivationalMessage {
    if (currentStreak == 0 && totalChaptersRead == 0) {
      return 'Que tal começar sua jornada de leitura hoje? 📖';
    }
    
    if (currentStreak >= 30) {
      return 'Incrível! $currentStreak dias seguidos lendo! Você é extraordinário! 🔥';
    }
    
    if (currentStreak >= 14) {
      return 'Fantástico! $currentStreak dias consecutivos! Continue assim! ⭐';
    }
    
    if (currentStreak >= 7) {
      return 'Uma semana inteira lendo! Que disciplina admirável! 💎';
    }
    
    if (currentStreak >= 3) {
      return '$currentStreak dias seguidos! Você está criando um ótimo hábito! 📚';
    }
    
    if (readToday) {
      return 'Parabéns por ler hoje! Continue construindo seu hábito! 🌟';
    }
    
    if (daysSinceLastReading == 1) {
      return 'Você leu ontem! Que tal continuar hoje para manter a sequência? 💪';
    }
    
    if (daysSinceLastReading <= 3) {
      return 'Está há $daysSinceLastReading dias sem ler. Que tal retomar hoje? 📖';
    }
    
    return 'A Palavra está esperando por você! Comece um novo capítulo hoje! ✨';
  }

  @override
  String toString() {
    return 'ReadingStatsModel(totalDays: $totalDaysReading, streak: $currentStreak, chapters: $totalChaptersRead, level: $readerLevel)';
  }
}
