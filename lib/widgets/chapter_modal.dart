import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/bible_repository.dart';
import '../services/themes/theme_manager.dart';

class ChapterModal extends StatefulWidget {
  final String bookName;
  final int chapter;
  final int highlightVerse;

  const ChapterModal({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.highlightVerse,
  });

  @override
  State<ChapterModal> createState() => _ChapterModalState();
}

class _ChapterModalState extends State<ChapterModal> {
  final BibleRepository _repository = BibleRepository();
  List<Map<String, dynamic>> _verses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    try {
      final verses = await _repository.getChapterVerses(
        bookName: widget.bookName,
        chapter: widget.chapter,
      );
      
      setState(() {
        _verses = verses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar capítulo: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeManager.primaryColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bookName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Capítulo ${widget.chapter}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Conteúdo
                Expanded(
                  child: _buildContent(themeManager),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeManager themeManager) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: themeManager.primaryColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_verses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nenhum versículo encontrado para este capítulo.',
            style: TextStyle(
              fontSize: 16,
              color: themeManager.primaryTextColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Versículos
          ..._verses.map((verse) => _buildVerseWidget(verse, themeManager)),
        ],
      ),
    );
  }

  Widget _buildVerseWidget(Map<String, dynamic> verse, ThemeManager themeManager) {
    final verseNumber = verse['verse_number'] as int;
    final verseText = verse['text'] as String;
    final isHighlighted = verseNumber == widget.highlightVerse;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted 
            ? themeManager.secondaryColor.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted 
            ? Border.all(
                color: themeManager.secondaryColor,
                width: 2,
              )
            : null,
      ),
      child: RichText(
        text: TextSpan(
          children: [
            // Número do versículo
            TextSpan(
              text: '$verseNumber ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHighlighted 
                    ? themeManager.primaryColor
                    : themeManager.primaryColor,
              ),
            ),
            // Texto do versículo
            TextSpan(
              text: verseText,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: isHighlighted 
                    ? themeManager.primaryTextColor
                    : themeManager.primaryTextColor.withOpacity(0.8),
                fontWeight: isHighlighted 
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Função helper para mostrar o modal
Future<void> showChapterModal({
  required BuildContext context,
  required String bookName,
  required int chapter,
  required int highlightVerse,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return ChapterModal(
        bookName: bookName,
        chapter: chapter,
        highlightVerse: highlightVerse,
      );
    },
  );
}
