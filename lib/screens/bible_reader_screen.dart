import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../database/bible_repository.dart';
import '../models/bible_book.dart';
import '../models/bible_verse.dart';
import '../services/bible_settings_service.dart';
import '../services/reading_history_service.dart';
import '../providers/game_provider.dart';
import '../widgets/bible_version_selector.dart';

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final BibleRepository _repository = BibleRepository();
  final ScrollController _scrollController = ScrollController();
  final ReadingHistoryService _readingService = ReadingHistoryService();
  final FlutterTts _flutterTts = FlutterTts();
  List<BibleBook> _books = [];
  List<BibleVerse> _verses = [];
  String _selectedVersion = '';
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;
  bool _isLoading = false;
  bool _isReadingMode = false;
  bool _showVerseSelector = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  int _currentReadingVerse = -1;
  // Controle de tempo de leitura para recompensas
  Timer? _readingTimer;
  bool _rewardGiven = false;

  Future<void> _speakChapter() async {
    if (_verses.isEmpty) return;
    
    if (mounted) {
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
        _currentReadingVerse = 0;
      });
    }
    
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.5);
    
    // Configurar callbacks para controle sequencial
    _flutterTts.setCompletionHandler(() {
      _onVerseCompleted();
    });
    
    _flutterTts.setErrorHandler((message) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentReadingVerse = -1;
        });
      }
    });
    
    // Começar a leitura do primeiro versículo
    _speakCurrentVerse();
  }

  Future<void> _speakCurrentVerse() async {
    if (_currentReadingVerse >= _verses.length || _currentReadingVerse < 0 || !_isSpeaking) {
      // Fim da leitura ou leitura foi interrompida
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentReadingVerse = -1;
        });
      }
      return;
    }
    
    final verse = _verses[_currentReadingVerse];
    
    // Destacar versículo atual e fazer scroll
    if (mounted) {
      setState(() {
        _selectedVerse = verse.verse;
      });
    }
    _scrollToVerse(verse.verse);
    
    // Falar o versículo atual apenas se ainda estamos em modo de leitura e não pausado
    if (_isSpeaking && !_isPaused) {
      final text = '${verse.verse}. ${verse.text}';
      await _flutterTts.speak(text);
    }
  }

  void _onVerseCompleted() {
    if (_isSpeaking && !_isPaused) {
      _currentReadingVerse++;
      // Pequena pausa entre versículos para melhor compreensão
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isSpeaking && !_isPaused && mounted) {
          _speakCurrentVerse();
        }
      });
    }
  }

  Future<void> _pauseTTS() async {
    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
      if (mounted) {
        setState(() {
          _isPaused = true;
        });
      }
    }
  }

  Future<void> _resumeTTS() async {
    if (_isPaused) {
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
      }
      // Continuar da onde parou
      if (_isSpeaking && _currentReadingVerse >= 0 && _currentReadingVerse < _verses.length) {
        _speakCurrentVerse();
      }
    }
  }

  Future<void> _stopTTS() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentReadingVerse = -1;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentVersionAndBooks();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _scrollController.dispose();
    _flutterTts.stop();
    // Remover handlers do TTS para evitar callbacks após dispose
    _flutterTts.setCompletionHandler(() {});
    _flutterTts.setErrorHandler((message) {});
    super.dispose();
  }

  Future<void> _loadCurrentVersionAndBooks() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final settingsService = BibleSettingsService();
      _selectedVersion = await settingsService.getCurrentBibleVersion();
      
      await _loadBooks();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError('Erro ao carregar: $e');
    }
  }

  Future<void> _loadBooks() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final booksData = await _repository.getAllBooks(_selectedVersion);
      final books = booksData.map((data) => BibleBook.fromMap(data)).toList();
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError('Erro ao carregar livros: $e');
    }
  }

  Future<void> _loadChapter(String bookName, int chapter, {bool directRead = false}) async {
      // Parar qualquer leitura em andamento
      await _stopTTS();
      
      if (mounted) {
        setState(() => _isLoading = true);
      }
      try {
        final versesData = await _repository.getVersesByChapter(_selectedVersion, bookName, chapter);
      
        if (versesData.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          _showError('Nenhum versículo encontrado para $bookName $chapter');
          return;
        }

        final verses = versesData.map((data) => BibleVerse.fromMap({
          ...data,
          'book': bookName,
          'chapter': chapter,
          'version': _selectedVersion,
        })).toList();
      
        setState(() {
          _selectedBook = bookName;
          _selectedChapter = chapter;
          _verses = verses;
          _showVerseSelector = directRead ? false : true;
          _isReadingMode = directRead ? true : false;
          _isLoading = false;
          _rewardGiven = false;
          // Reset reading state
          _currentReadingVerse = -1;
          _selectedVerse = null;
        });
        for (int i = 0; i < verses.length && i < 10; i++) {
          print('   ${verses[i].verse}: "${verses[i].text.substring(0, math.min(50, verses[i].text.length))}..."');
        }
        
        // Criar mapa para versículos únicos - sempre manter o primeiro encontrado
        final Map<int, BibleVerse> uniqueVerses = {};
        
        for (final verse in verses) {
          final verseNum = verse.verse;
          
          // Se o versículo ainda não existe, adicionar
          // Se já existe, manter o que tem texto mais longo OU diferente
          if (!uniqueVerses.containsKey(verseNum)) {
            uniqueVerses[verseNum] = verse;
            print('   ✅ Adicionado versículo $verseNum');
          } else {
            final existing = uniqueVerses[verseNum]!;
            print('   ⚠️  Duplicata encontrada no versículo $verseNum:');
            print('      Existente: "${existing.text.substring(0, math.min(30, existing.text.length))}..."');
            print('      Novo: "${verse.text.substring(0, math.min(30, verse.text.length))}..."');
            
            // Comparar textos e manter o melhor
            if (verse.text != existing.text && verse.text.length > existing.text.length) {
              uniqueVerses[verseNum] = verse;
              print('      -> Substituído pelo texto mais longo');
            } else {
              print('      -> Mantido o existente');
            }
          }
        }
        
        // Ordenar os versículos por número
        final filteredVerses = uniqueVerses.values.toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));

        print('✅ Resultado final: ${filteredVerses.length} versículos únicos');
        if (verses.length != filteredVerses.length) {
          print('�️  Removidas ${verses.length - filteredVerses.length} duplicatas');
        }
      
        if (mounted) {
          setState(() {
            _selectedBook = bookName;
            _selectedChapter = chapter;
            _verses = verses;
            _showVerseSelector = directRead ? false : true;
            _isReadingMode = directRead ? true : false;
            _isLoading = false;
            _rewardGiven = false;
            // Reset reading state
            _currentReadingVerse = -1;
            _selectedVerse = null;
          });
        }

      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        _showError('Erro ao carregar capítulo: $e');
      }
    }

  /// Inicia uma nova sessão de leitura com controle de tempo
  void _startReadingSession() {
    _readingTimer?.cancel();
    
    // Aguarda 5 segundos antes de dar a recompensa
    _readingTimer = Timer(const Duration(seconds: 5), () {
      if (!_rewardGiven && mounted) {
        _recordChapterReadingAfterTime();
      }
    });
  }

  /// Registra a leitura após o tempo mínimo de engajamento
  Future<void> _recordChapterReadingAfterTime() async {
    if (_selectedBook == null || _selectedChapter == null || _rewardGiven) return;

    try {
      final wasRecorded = await _readingService.recordChapterRead(
        bookName: _selectedBook!,
        chapter: _selectedChapter!,
        bibleVersion: _selectedVersion,
      );

      if (wasRecorded && mounted) {
        setState(() {
          _rewardGiven = true;
        });
        
        if (mounted) {
          final gameProvider = Provider.of<GameProvider>(context, listen: false);
          gameProvider.addExperience(10);
          await gameProvider.reloadStats(force: true);
        }
      
      }
    } catch (e) {
      print('❌ Erro ao registrar leitura: $e');
    }
  }

  void _selectVerse(int verseNumber) {
    setState(() {
      _selectedVerse = verseNumber;
      _isReadingMode = true;
      _showVerseSelector = false;
    });
    
    _startReadingSession();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToVerse(verseNumber);
    });
  }

  void _scrollToVerse(int verseNumber) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && _verses.isNotEmpty) {
        final index = _verses.indexWhere((v) => v.verse == verseNumber);
        if (index >= 0) {
          // Calcular posição mais precisa baseada no índice real
          final double itemHeight = 80.0; // Altura estimada de cada item
          final double targetPosition = index * itemHeight;
          final double maxScroll = _scrollController.position.maxScrollExtent;
          
          // Ajustar posição para centralizar o item na tela quando possível
          final double viewportHeight = _scrollController.position.viewportDimension;
          final double centeredPosition = targetPosition - (viewportHeight / 2) + (itemHeight / 2);
          
          final double adjustedPosition = centeredPosition < 0 
              ? 0 
              : (centeredPosition > maxScroll ? maxScroll : centeredPosition);
          
          _scrollController.animateTo(
            adjustedPosition,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _showBibleVersionDialog(BuildContext context, ThemeManager themeManager) {
    showDialog(
      context: context,
      builder: (context) => BibleVersionDialog(
        currentVersion: _selectedVersion,
        onVersionChanged: (newVersion) {
          if (mounted) {
            setState(() {
              _selectedVersion = newVersion;
            });
          }
          if (_books.isNotEmpty) {
            _loadBooks();
          }
        },
      ),
    );
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _backToBooks() {
    // Parar leitura ao voltar
    _stopTTS();
    if (mounted) {
      setState(() {
        _isReadingMode = false;
        _showVerseSelector = false;
        _selectedBook = null;
        _selectedChapter = null;
        _selectedVerse = null;
        _verses.clear();
        _currentReadingVerse = -1;
      });
    }
  }

  void _backToVerseSelector() {
    // Parar leitura ao voltar
    _stopTTS();
    if (mounted) {
      setState(() {
        _isReadingMode = false;
        _showVerseSelector = true;
        _selectedVerse = null;
        _currentReadingVerse = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: (_isReadingMode || _showVerseSelector)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: _isReadingMode
                        ? 'Voltar para seleção de versículo'
                        : 'Voltar para livros',
                    onPressed: () {
                      if (_isReadingMode) {
                        _backToVerseSelector();
                      } else {
                        _backToBooks();
                      }
                    },
                  )
                : null,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isReadingMode 
                      ? '$_selectedBook $_selectedChapter${_selectedVerse != null ? ':$_selectedVerse' : ''}'
                      : _showVerseSelector
                        ? '$_selectedBook $_selectedChapter'
                        : 'Leitor Bíblico',
                    style: TextStyle(
                      color: themeManager.primaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_isReadingMode && !_showVerseSelector)
                  InkWell(
                    onTap: () => _showBibleVersionDialog(context, themeManager),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            _selectedVersion.toUpperCase(),
                            style: TextStyle(
                              color: themeManager.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            color: themeManager.primaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            backgroundColor: themeManager.backgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(color: themeManager.primaryTextColor),
            actions: [
              if (_isReadingMode)
                IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  onPressed: _backToVerseSelector,
                  tooltip: 'Escolher versículo',
                ),
              if (_isReadingMode || _showVerseSelector)
                IconButton(
                  icon: const Icon(Icons.menu_book),
                  onPressed: _backToBooks,
                  tooltip: 'Voltar aos livros',
                ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: themeManager.primaryColor,
                  ),
                )
              : _showVerseSelector
                  ? _buildVerseSelector(themeManager)
                  : _isReadingMode
                      ? _buildChapterView(themeManager)
                      : _buildBooksView(themeManager),
        );
      },
    );
  }

  Widget _buildBooksView(ThemeManager themeManager) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _books.length,
            itemBuilder: (context, index) {
              final book = _books[index];
              return _BookExpansionTile(
                book: book,
                themeManager: themeManager,
                onChapterSelected: (chapter) => _loadChapter(book.name, chapter, directRead: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVerseSelector(ThemeManager themeManager) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeManager.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeManager.primaryColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: themeManager.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: themeManager.primaryColor.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedBook ?? '',
                              style: TextStyle(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Capítulo ${_selectedChapter ?? ''}',
                              style: TextStyle(
                                color: themeManager.secondaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book,
                              color: themeManager.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedVersion.toUpperCase(),
                              style: TextStyle(
                                color: themeManager.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: _verses.length,
              itemBuilder: (context, index) {
                final verse = _verses[index];
                return InkWell(
                  onTap: () => _selectVerse(verse.verse),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeManager.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        verse.verse.toString(),
                        style: TextStyle(
                          color: themeManager.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterView(ThemeManager themeManager) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _verses.length,
            itemBuilder: (context, index) {
              final verse = _verses[index];
              final isSelected = _selectedVerse == verse.verse;
              final isCurrentlyReading = _isSpeaking && _currentReadingVerse >= 0 && 
                                       _currentReadingVerse < _verses.length && 
                                       _verses[_currentReadingVerse].verse == verse.verse;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedVerse = verse.verse),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentlyReading
                        ? themeManager.primaryColor.withOpacity(0.25)
                        : isSelected
                            ? themeManager.primaryColor.withOpacity(0.15)
                            : themeManager.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentlyReading
                          ? themeManager.primaryColor
                          : isSelected
                              ? themeManager.primaryColor.withOpacity(0.5)
                              : themeManager.primaryColor.withOpacity(0.1),
                      width: isCurrentlyReading ? 3 : (isSelected ? 2 : 1),
                    ),
                    boxShadow: (isSelected || isCurrentlyReading)
                        ? [
                            BoxShadow(
                              color: themeManager.primaryColor.withOpacity(0.2),
                              blurRadius: isCurrentlyReading ? 8 : 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (isCurrentlyReading)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Icon(
                            _isPaused ? Icons.pause : Icons.volume_up,
                            color: themeManager.primaryColor,
                            size: 18,
                          ),
                        ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${verse.verse} ',
                                style: TextStyle(
                                  color: themeManager.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCurrentlyReading ? 15 : 14,
                                ),
                              ),
                              TextSpan(
                                text: verse.text,
                                style: TextStyle(
                                  color: themeManager.primaryTextColor,
                                  fontSize: isCurrentlyReading ? 17 : 16,
                                  height: 1.6,
                                  fontWeight: isCurrentlyReading ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          bottom: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: themeManager.surfaceColor,
              border: Border(top: BorderSide(color: themeManager.primaryColor.withOpacity(0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  tooltip: 'Capítulo anterior',
                  color: themeManager.primaryColor,
                  onPressed: (_selectedChapter ?? 1) > 1
                      ? () async {
                          await _stopTTS();
                          setState(() => _selectedVerse = null);
                          _loadChapter(_selectedBook!, (_selectedChapter ?? 1) - 1, directRead: true);
                        }
                      : null,
                ),
                // PAUSE: sempre visível, só ativa durante leitura ativa
                IconButton(
                  icon: const Icon(Icons.pause_circle_filled, size: 28),
                  tooltip: 'Pausar leitura',
                  color: themeManager.primaryColor,
                  onPressed: (_isSpeaking && !_isPaused) ? _pauseTTS : null,
                ),
                // PLAY: sempre visível, só desativa durante leitura ativa
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, size: 32),
                  tooltip: !_isSpeaking ? 'Ouvir capítulo' : (_isPaused ? 'Retomar leitura' : 'Lendo capítulo...'),
                  color: themeManager.primaryColor,
                  onPressed: (!_isSpeaking || _isPaused) ? (!_isSpeaking ? _speakChapter : _resumeTTS) : null,
                ),
                // STOP: sempre visível, só ativa durante leitura ou pausa
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 28),
                  tooltip: 'Parar leitura',
                  color: themeManager.primaryColor,
                  onPressed: (_isSpeaking || _isPaused) ? _stopTTS : null,
                ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Próximo capítulo',
                    color: themeManager.primaryColor,
                    onPressed: (() {
                      final book = _books.firstWhere((b) => b.name == _selectedBook, orElse: () => BibleBook(name: '', chapters: 1, testament: 'AT'));
                      if ((_selectedChapter ?? 1) < book.chapters) {
                        return () async {
                          await _stopTTS();
                          setState(() => _selectedVerse = null);
                          _loadChapter(_selectedBook!, (_selectedChapter ?? 1) + 1, directRead: true);
                        };
                      }
                      return null;
                    })(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Widget para expansão de livros com capítulos
class _BookExpansionTile extends StatefulWidget {
  final BibleBook book;
  final ThemeManager themeManager;
  final Function(int) onChapterSelected;

  const _BookExpansionTile({
    required this.book,
    required this.themeManager,
    required this.onChapterSelected,
  });

  @override
  State<_BookExpansionTile> createState() => _BookExpansionTileState();
}

class _BookExpansionTileState extends State<_BookExpansionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.themeManager.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.themeManager.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.book.testament == 'AT' ? 'AT' : 'NT',
                        style: TextStyle(
                          color: widget.themeManager.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.name,
                          style: TextStyle(
                            color: widget.themeManager.primaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.book.chapters} capítulos',
                          style: TextStyle(
                            color: widget.themeManager.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.themeManager.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.themeManager.backgroundColor.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: _buildChapterGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.book.chapters,
      itemBuilder: (context, index) {
        final chapter = index + 1;
        return InkWell(
          onTap: () => widget.onChapterSelected(chapter),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: widget.themeManager.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.themeManager.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                chapter.toString(),
                style: TextStyle(
                  color: widget.themeManager.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

