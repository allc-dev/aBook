import 'package:uuid/uuid.dart';

enum SessionStatus { active, completed, abandoned }

class GameSessionModel {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final String difficultyLevel;
  SessionStatus status;
  
  int totalQuestions = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int totalPoints = 0;
  int bestStreak = 0;
  int currentStreak = 0;
  int maxErrors = 3;
  
  GameSessionModel({
    String? id,
    DateTime? startTime,
    required this.difficultyLevel,
    this.endTime,
    this.status = SessionStatus.active,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.totalPoints = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
  }) : id = id ?? const Uuid().v4(),
       startTime = startTime ?? DateTime.now();

  // Getters calculados
  bool get isActive => status == SessionStatus.active;
  bool get isCompleted => status == SessionStatus.completed;
  bool get isAbandoned => status == SessionStatus.abandoned;
  bool get isGameOver => wrongAnswers >= maxErrors;
  
  double get accuracy => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
  
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
  
  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}min';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}min ${d.inSeconds % 60}s';
    } else {
      return '${d.inSeconds}s';
    }
  }

  // Métodos para atualizar o estado da sessão
  void addCorrectAnswer(int points) {
    totalQuestions++;
    correctAnswers++;
    totalPoints += points;
    currentStreak++;
    
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }
  }
  
  void addWrongAnswer() {
    totalQuestions++;
    wrongAnswers++;
    currentStreak = 0;
    
    if (isGameOver) {
      endSession();
    }
  }
  
  void endSession() {
    endTime = DateTime.now();
    status = SessionStatus.completed;
  }
  
  void abandonSession() {
    endTime = DateTime.now();
    status = SessionStatus.abandoned;
  }

  // Conversões para banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'difficulty_level': difficultyLevel,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'total_points': totalPoints,
      'session_completed': status == SessionStatus.completed ? 1 : 0,
      'best_streak': bestStreak,
    };
  }
  
  factory GameSessionModel.fromMap(Map<String, dynamic> map) {
    return GameSessionModel(
      id: map['id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      difficultyLevel: map['difficulty_level'] as String,
      totalQuestions: map['total_questions'] as int? ?? 0,
      correctAnswers: map['correct_answers'] as int? ?? 0,
      wrongAnswers: map['wrong_answers'] as int? ?? 0,
      totalPoints: map['total_points'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      status: (map['session_completed'] as int? ?? 0) == 1 
          ? SessionStatus.completed 
          : SessionStatus.active,
    );
  }

  @override
  String toString() {
    return 'GameSession(id: $id, difficulty: $difficultyLevel, questions: $totalQuestions, correct: $correctAnswers, points: $totalPoints, status: $status)';
  }
}

// Modelo para estatísticas diárias
class DailyStatsModel {
  final String date;
  int sessionsPlayed;
  int totalQuestions;
  int correctAnswers;
  int totalPoints;
  int bestSessionPoints;
  int easyCorrect;
  int mediumCorrect;
  int hardCorrect;
  
  DailyStatsModel({
    required this.date,
    this.sessionsPlayed = 0,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.totalPoints = 0,
    this.bestSessionPoints = 0,
    this.easyCorrect = 0,
    this.mediumCorrect = 0,
    this.hardCorrect = 0,
  });
  
  double get accuracy => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
  
  void updateWithSession(GameSessionModel session) {
    sessionsPlayed++;
    totalQuestions += session.totalQuestions;
    correctAnswers += session.correctAnswers;
    totalPoints += session.totalPoints;
    
    if (session.totalPoints > bestSessionPoints) {
      bestSessionPoints = session.totalPoints;
    }
    
    // Contabilizar por dificuldade (aproximação)
    switch (session.difficultyLevel.toLowerCase()) {
      case 'fácil':
        easyCorrect += session.correctAnswers;
        break;
      case 'médio':
        mediumCorrect += session.correctAnswers;
        break;
      case 'difícil':
        hardCorrect += session.correctAnswers;
        break;
    }
  }
  
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'sessions_played': sessionsPlayed,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'total_points': totalPoints,
      'best_session_points': bestSessionPoints,
      'easy_correct': easyCorrect,
      'medium_correct': mediumCorrect,
      'hard_correct': hardCorrect,
    };
  }
  
  factory DailyStatsModel.fromMap(Map<String, dynamic> map) {
    return DailyStatsModel(
      date: map['date'] as String,
      sessionsPlayed: map['sessions_played'] as int? ?? 0,
      totalQuestions: map['total_questions'] as int? ?? 0,
      correctAnswers: map['correct_answers'] as int? ?? 0,
      totalPoints: map['total_points'] as int? ?? 0,
      bestSessionPoints: map['best_session_points'] as int? ?? 0,
      easyCorrect: map['easy_correct'] as int? ?? 0,
      mediumCorrect: map['medium_correct'] as int? ?? 0,
      hardCorrect: map['hard_correct'] as int? ?? 0,
    );
  }
}
