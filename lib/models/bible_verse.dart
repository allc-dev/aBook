class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final String version;

  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.version,
  });

  factory BibleVerse.fromMap(Map<String, dynamic> map) {
    return BibleVerse(
      book: map['book'] ?? '',
      chapter: map['chapter'] ?? 0,
      verse: map['verse'] ?? 0,
      text: map['text'] ?? '',
      version: map['version'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'version': version,
    };
  }
}
