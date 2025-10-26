// Enumeração para níveis de dificuldade
enum DifficultyLevel {
  easy(1, 'Fácil'),
  medium(2, 'Médio'),
  hard(3, 'Difícil');
  
  const DifficultyLevel(this.value, this.name);
  
  final int value;
  final String name;
  
  static DifficultyLevel fromValue(int value) {
    switch (value) {
      case 1:
        return DifficultyLevel.easy;
      case 2:
        return DifficultyLevel.medium;
      case 3:
        return DifficultyLevel.hard;
      default:
        return DifficultyLevel.medium;
    }
  }
}

class VerseModel {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String? bookName;
  final String? difficultyLevel;
  final int? pointsValue;

  VerseModel({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.bookName,
    this.difficultyLevel,
    this.pointsValue,
  });

  factory VerseModel.fromMap(Map<String, dynamic> map) {
    return VerseModel(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      bookName: map['book_name'] as String?,
      difficultyLevel: map['difficulty_level'] as String?,
      pointsValue: map['points_value'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'book_name': bookName,
      'difficulty_level': difficultyLevel,
      'points_value': pointsValue,
    };
  }

  String get reference => '$bookName $chapter:$verse';
  
  String get shortReference => '${bookName?.substring(0, (bookName?.length ?? 0) > 10 ? 10 : null)}${(bookName?.length ?? 0) > 10 ? '...' : ''} $chapter:$verse';

  @override
  String toString() {
    return 'VerseModel(id: $id, bookName: $bookName, chapter: $chapter, verse: $verse, text: ${text.substring(0, text.length > 50 ? 50 : null)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
