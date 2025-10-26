import 'verse_model.dart';

class QuestionModel {
  final VerseModel verse;
  final List<String> alternatives;
  final String correctAnswer;
  final String difficulty;
  final int pointsValue;
  final DateTime createdAt;
  
  String? selectedAnswer;
  bool? isCorrect;
  int? timeToAnswer;
  
  QuestionModel({
    required this.verse,
    required this.alternatives,
    required this.correctAnswer,
    required this.difficulty,
    required this.pointsValue,
    DateTime? createdAt,
    this.selectedAnswer,
    this.isCorrect,
    this.timeToAnswer,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAnswered => selectedAnswer != null;
  
  bool get wasCorrect => isCorrect == true;
  
  int get pointsEarned => (isCorrect == true) ? pointsValue : 0;
  
  /// Embaralha as alternativas incluindo a resposta correta
  List<String> get shuffledAlternatives {
    final List<String> allOptions = [correctAnswer, ...alternatives];
    allOptions.shuffle();
    return allOptions;
  }
  
  /// Submete uma resposta para a pergunta
  void submitAnswer(String answer, int timeInSeconds) {
    selectedAnswer = answer;
    isCorrect = answer == correctAnswer;
    timeToAnswer = timeInSeconds;
  }
  
  /// Verifica se uma alternativa específica é a correta
  bool isCorrectAnswer(String answer) {
    return answer == correctAnswer;
  }
  
  /// Converte para Map para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'verse_id': verse.id,
      'correct_answer': correctAnswer,
      'alternatives': alternatives.join('|'),
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect == true ? 1 : 0,
      'difficulty': difficulty,
      'points_value': pointsValue,
      'points_earned': pointsEarned,
      'time_to_answer': timeToAnswer,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  factory QuestionModel.fromMap(Map<String, dynamic> map, VerseModel verse) {
    return QuestionModel(
      verse: verse,
      correctAnswer: map['correct_answer'] as String,
      alternatives: (map['alternatives'] as String).split('|'),
      selectedAnswer: map['selected_answer'] as String?,
      difficulty: map['difficulty'] as String,
      pointsValue: map['points_value'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      timeToAnswer: map['time_to_answer'] as int?,
    );
  }

  @override
  String toString() {
    return 'QuestionModel(verse: ${verse.shortReference}, difficulty: $difficulty, points: $pointsValue, answered: $isAnswered)';
  }
}
