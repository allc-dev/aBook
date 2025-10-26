/// Modelo para representar um registro de leitura
class ReadingHistoryModel {
  final int? id;
  final String bookName;
  final int chapter;
  final String bibleVersion;
  final DateTime readDate;
  final int pointsEarned;

  ReadingHistoryModel({
    this.id,
    required this.bookName,
    required this.chapter,
    required this.bibleVersion,
    required this.readDate,
    this.pointsEarned = 10, // 10 pontos por capítulo lido
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_name': bookName,
      'chapter': chapter,
      'bible_version': bibleVersion,
      'read_date': readDate.toIso8601String().split('T')[0],
      'points_earned': pointsEarned,
    };
  }

  factory ReadingHistoryModel.fromMap(Map<String, dynamic> map) {
    return ReadingHistoryModel(
      id: map['id'],
      bookName: map['book_name'],
      chapter: map['chapter'],
      bibleVersion: map['bible_version'],
      readDate: DateTime.parse(map['read_date']),
      pointsEarned: map['points_earned'] ?? 5,
    );
  }

  /// Gera uma chave única para identificar leitura duplicada (mesmo dia, livro e capítulo)
  String get uniqueKey => '${readDate.toIso8601String().split('T')[0]}_${bookName}_$chapter';

  @override
  String toString() {
    return 'ReadingHistoryModel(bookName: $bookName, chapter: $chapter, readDate: $readDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingHistoryModel &&
        other.bookName == bookName &&
        other.chapter == chapter &&
        other.readDate.day == readDate.day &&
        other.readDate.month == readDate.month &&
        other.readDate.year == readDate.year;
  }

  @override
  int get hashCode => uniqueKey.hashCode;
}
