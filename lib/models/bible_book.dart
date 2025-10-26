class BibleBook {
  final String name;
  final int chapters;
  final String testament;

  BibleBook({
    required this.name,
    required this.chapters,
    required this.testament,
  });

  factory BibleBook.fromMap(Map<String, dynamic> map) {
    return BibleBook(
      name: map['name'] ?? '',
      chapters: map['chapters'] ?? 0,
      testament: map['testament'] ?? 'AT',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'chapters': chapters,
      'testament': testament,
    };
  }
}
