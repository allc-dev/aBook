import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/bible_repository.dart';
import '../services/themes/theme_manager.dart';

class VerseHintModal extends StatefulWidget {
  final String bookName;
  final int chapter;
  final int centerVerse;

  const VerseHintModal({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.centerVerse,
  });

  @override
  State<VerseHintModal> createState() => _VerseHintModalState();
}

class _VerseHintModalState extends State<VerseHintModal> {
  final BibleRepository _repository = BibleRepository();
  List<Map<String, dynamic>> _verses = [];
  bool _isLoading = true;
  String? _error;
  String? _testamentType;
  int? _totalVerses;

  @override
  void initState() {
    super.initState();
    _loadHintVerses();
    _setTestamentType();
  }

  void _setTestamentType() {
    // Livros do AT
    const atBooks = [
      'Gênesis','Êxodo','Levítico','Números','Deuteronômio','Josué','Juízes','Rute','1 Samuel','2 Samuel','1 Reis','2 Reis','1 Crônicas','2 Crônicas','Esdras','Neemias','Ester','Jó','Salmos','Provérbios','Eclesiastes','Cânticos','Cantares','Isaías','Jeremias','Lamentações','Ezequiel','Daniel','Oséias','Joel','Amós','Obadias','Jonas','Miquéias','Naum','Habacuque','Sofonias','Ageu','Zacarias','Malaquias'
    ];
    setState(() {
      _testamentType = atBooks.contains(widget.bookName) ? 'AT' : 'NT';
    });
  }

  Future<void> _loadHintVerses() async {
    try {
      // Buscar todos os versículos do capítulo
      final allVerses = await _repository.getChapterVerses(
        bookName: widget.bookName,
        chapter: widget.chapter,
      );
      _totalVerses = allVerses.length;

      if (allVerses.isEmpty) {
        setState(() {
          _error = 'Nenhum versículo encontrado para este capítulo.';
          _isLoading = false;
        });
        return;
      }

      // Calcular o range de versículos (2 antes + o versículo central + 2 depois)
      final centerIndex = allVerses.indexWhere(
        (verse) => verse['verse_number'] == widget.centerVerse,
      );
      
      List<Map<String, dynamic>> hintVerses;
      
      if (centerIndex == -1) {
        // Se não encontrou o versículo central, pegar os primeiros 5
        hintVerses = allVerses.take(5).toList();
      } else {
        // Calcular início e fim do range
        final startIndex = (centerIndex - 2).clamp(0, allVerses.length - 1);
        final endIndex = (centerIndex + 2).clamp(0, allVerses.length - 1);
        
        // Ajustar para sempre ter 5 versículos (quando possível)
        int adjustedStart = startIndex;
        int adjustedEnd = endIndex;
        
        // Se há menos de 5 versículos no range, expandir
        final currentCount = adjustedEnd - adjustedStart + 1;
        if (currentCount < 5) {
          final needed = 5 - currentCount;
          
          // Tentar expandir para trás primeiro
          if (adjustedStart > 0) {
            final canExpand = (adjustedStart - 0).clamp(0, needed);
            adjustedStart -= canExpand;
          }
          
          // Se ainda precisa, expandir para frente
          if (adjustedEnd < allVerses.length - 1 && (adjustedEnd - adjustedStart + 1) < 5) {
            final stillNeeded = 5 - (adjustedEnd - adjustedStart + 1);
            final canExpand = (allVerses.length - 1 - adjustedEnd).clamp(0, stillNeeded);
            adjustedEnd += canExpand;
          }
        }
        
        hintVerses = allVerses.sublist(
          adjustedStart,
          (adjustedEnd + 1).clamp(0, allVerses.length),
        );
      }
      
      setState(() {
        _verses = hintVerses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar versículos: $e';
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
                  // Cabeçalho com "Dica" e número do capítulo
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
                                'Dica',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_testamentType != null)
                              Text(
                                '${_testamentType!}  - Capítulo ${widget.chapter}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                              if (_totalVerses != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Total de versículos: ${_totalVerses!}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: themeManager.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Carregando dica...',
              style: TextStyle(
                color: themeManager.secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
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
              Icon(
                Icons.error_outline,
                size: 48,
                color: themeManager.incorrectColor,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 16,
                  color: themeManager.incorrectColor,
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
    final isTargetVerse = verseNumber == widget.centerVerse;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTargetVerse 
            ? themeManager.secondaryColor.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isTargetVerse 
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
                color: isTargetVerse 
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
                color: isTargetVerse 
                    ? themeManager.primaryTextColor
                    : themeManager.primaryTextColor.withOpacity(0.8),
                fontWeight: isTargetVerse 
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

// Função helper para mostrar o modal de dica
Future<void> showVerseHintModal({
  required BuildContext context,
  required String bookName,
  required int chapter,
  required int centerVerse,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return VerseHintModal(
        bookName: bookName,
        chapter: chapter,
        centerVerse: centerVerse,
      );
    },
  );
}
