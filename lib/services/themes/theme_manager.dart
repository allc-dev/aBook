import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_preset.dart';
import 'theme_presets.dart';

class ThemeManager extends ChangeNotifier {
  static const String _themeIndexKey = 'bible_theme_preset_index';

  int _currentThemeIndex = 0;
  bool? _isPremium;
  late AppThemePreset _currentTheme;

  /// O status PRO deve ser setado explicitamente via setPremiumStatusSync antes de qualquer uso!
  ThemeManager() {
    _currentTheme = defaultTheme;
  }

  /// Inicializa o status PRO de forma síncrona. Obrigatório antes de qualquer uso do ThemeManager!
  void setPremiumStatusSync(bool isPremium) {
    _isPremium = isPremium;
  }

  /// Retorna todos os temas, inclusive os premium, sem filtrar por status.
  List<AppThemePreset> get allThemes => [...bibleFreeThemes, ...biblePremiumThemes];

  int get currentThemeIndex => _currentThemeIndex;
  
  /// Sempre use setPremiumStatusSync antes de qualquer acesso!
  bool get isPremium {
    assert(_isPremium != null, 'Premium status must be initialized before use!');
    if (_isPremium == null) {
      throw Exception('ThemeManager: premium status not initialized');
    }
    return _isPremium!;
  }
  
  AppThemePreset get currentTheme => _currentTheme;

  List<AppThemePreset> get availableThemes => getAvailableThemes(isPremium);

  // Getters para compatibilidade com o sistema existente
  Color get backgroundColor => _currentTheme.background;
  Color get fontColor => _currentTheme.font;
  Color get primaryColor => _currentTheme.primary;
  Color get secondaryColor => _currentTheme.secondary;
  Color get surfaceColor => _currentTheme.surface;
  Color get accentColor => _currentTheme.accentColor;
  Color get cardColor => _currentTheme.cardColor;
  Color get primaryTextColor => _currentTheme.primaryTextColor;
  Color get secondaryTextColor => _currentTheme.secondaryTextColor;
  Color get mutedTextColor => _currentTheme.mutedTextColor;

  // Getters específicos para o quiz bíblico
  Color get correctColor => _currentTheme.correct;
  Color get incorrectColor => _currentTheme.incorrect;
  Color get neutralColor => _currentTheme.neutral;
  Color get difficultyEasyColor => _currentTheme.difficultyEasy;
  Color get difficultyMediumColor => _currentTheme.difficultyMedium;
  Color get difficultyHardColor => _currentTheme.difficultyHard;

  /// Chame setPremiumStatusSync antes de chamar init!
  Future<void> init() async {
    if (_isPremium == null) {
      throw Exception('ThemeManager.init: premium status not initialized');
    }
    final prefs = await SharedPreferences.getInstance();
    await _loadSettings(prefs);
  }

  Future<void> _loadSettings(SharedPreferences prefs) async {
    _currentThemeIndex = prefs.getInt(_themeIndexKey) ?? 0;
    await _updateCurrentTheme();
    notifyListeners();
  }

  Future<void> setPremiumStatus(bool isPremium) async {
    if (_isPremium != isPremium) {
      _isPremium = isPremium;
      await _validateCurrentTheme();
      notifyListeners();
    }
  }

  Future<void> _validateCurrentTheme() async {
    if (_currentThemeIndex >= availableThemes.length) {
      await setTheme(0);
    }
  }

  Future<void> setTheme(int index) async {
    if (isThemePremium(index) && !isPremium) {
      throw Exception('Tema premium requer upgrade');
    }
    final theme = getThemeByIndex(index, isPremium);
    if (theme != null) {
      _currentThemeIndex = index;
      _currentTheme = theme;
      await _saveThemeIndex(index);
      notifyListeners();
    }
  }

  Future<void> _updateCurrentTheme() async {
    final theme = getThemeByIndex(_currentThemeIndex, isPremium);
    if (theme != null) {
      _currentTheme = theme;
    } else {
      _currentThemeIndex = 0;
      _currentTheme = defaultTheme;
      await _saveThemeIndex(0);
    }
  }

  Future<void> _saveThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeIndexKey, index);
  }

  String getThemeName(String key) {
    switch (key) {
      case 'classicBiblical':
        return 'Clássico Bíblico';
      case 'ancientParchment':
        return 'Pergaminho Antigo';
      case 'sereneNight':
        return 'Noite Serena';
      case 'wisdomBlue':
        return 'Azul Sabedoria';
      case 'sacredGold':
        return 'Ouro Sacro';
      case 'royalPurple':
        return 'Púrpura Real';
      case 'preciousEmerald':
        return 'Esmeralda Preciosa';
      case 'divineRuby':
        return 'Rubi Divino';
      case 'vintageCopper':
        return 'Cobre Vintage';
      case 'celestialSapphire':
        return 'Safira Celestial';
      case 'mysticAmethyst':
        return 'Ametista Mística';
      default:
        return key;
    }
  }

  Future<void> resetToDefault() async {
    await setTheme(0);
  }

  /// Verifica se um tema é premium
  bool isThemePremium(int index) {
    return index >= bibleFreeThemes.length;
  }

  /// Sincroniza o status premium
  void syncWithPurchaseService(bool isProVersion) {
    if (_isPremium != isProVersion) {
      _isPremium = isProVersion;
      if (!isProVersion && isThemePremium(_currentThemeIndex)) {
        // Se perdeu o PRO e está usando tema premium, volta para o padrão
        setTheme(0);
      } else if (isProVersion) {
        // Se virou PRO, restaura o tema salvo (pode ser premium)
        SharedPreferences.getInstance().then((prefs) async {
          _currentThemeIndex = prefs.getInt(_themeIndexKey) ?? 0;
          await _updateCurrentTheme();
          notifyListeners();
        });
      } else {
        notifyListeners();
      }
    }
  }
}
