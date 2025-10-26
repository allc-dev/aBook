import 'package:flutter/material.dart';
import 'theme_preset.dart';

// Temas gratuitos - focados na temática bíblica e educacional
const List<AppThemePreset> bibleFreeThemes = [
  // 1. Azul Sabedoria (padrão)
  AppThemePreset(
    'wisdomBlue',
    Color(0xFFF5F9FF),     // Fundo azul muito claro
    Color(0xFF0D47A1),     // Texto azul profundo
    Color(0xFF1976D2),     // Primary azul médio
    Color(0xFF64B5F6),     // Secondary azul claro
    Color(0xFFFFFFFF),     // Surface branco
  ),

  // 2. Pergaminho Antigo
  AppThemePreset(
    'ancientParchment',
    Color(0xFFFFFAF0),     // Fundo pergaminho claro
    Color(0xFF2C1810),     // Texto marrom profundo
    Color(0xFF8B5E3C),     // Primary marrom quente
    Color(0xFFD4AF37),     // Secondary dourado suave
    Color(0xFFFFFDF7),     // Surface quase branco
  ),

  // 3. Clássico Bíblico - Verde tradicional
  AppThemePreset(
    'classicBiblical',
    Color(0xFFFDFDFD),     // Fundo branco elegante
    Color(0xFF1B5E20),     // Texto verde escuro
    Color(0xFF2E7D32),     // Primary verde bíblico
    Color(0xFFD4AF37),     // Secondary dourado elegante
    Color(0xFFFFFFFF),     // Surface branco puro
  ),

  // 4. Noite Serena - Tema escuro
  AppThemePreset(
    'sereneNight',
    Color(0xFF121212),     // Fundo preto suave
    Color(0xFFE0E0E0),     // Texto cinza claro quase branco
    Color(0xFF4CAF50),     // Primary verde sereno
    Color(0xFFFFB74D),     // Secondary dourado quente
    Color(0xFF1E1E1E),     // Surface cinza grafite
  ),
];

// Temas premium - cores mais sofisticadas e exclusivas
const List<AppThemePreset> biblePremiumThemes = [
  // 5. Ouro Sacro
  AppThemePreset(
    'sacredGold',
    Color(0xFF1C1A14),     // Fundo marrom quase preto
    Color(0xFFFFF5CC),     // Texto dourado claro
    Color(0xFFD4AF37),     // Primary dourado
    Color(0xFFB8860B),     // Secondary dourado queimado
    Color(0xFF2C2416),     // Surface marrom escuro
  ),
  
  // 6. Púrpura Real
  AppThemePreset(
    'royalPurple',
    Color(0xFF1B1033),     // Fundo púrpura profundo
    Color(0xFFF3E5F5),     // Texto lilás claro
    Color(0xFF6A1B9A),     // Primary roxo real
    Color(0xFFAB47BC),     // Secondary roxo vibrante
    Color(0xFF2E1B47),     // Surface roxo escuro
  ),
  
  // 7. Esmeralda Preciosa
  AppThemePreset(
    'preciousEmerald',
    Color(0xFF0D1F14),     // Fundo verde quase preto
    Color(0xFFDCEDC8),     // Texto verde claro
    Color(0xFF2E7D32),     // Primary verde esmeralda
    Color(0xFF66BB6A),     // Secondary verde mais suave
    Color(0xFF1B3A2E),     // Surface verde escuro
  ),
  
  // 8. Rubi Divino
  AppThemePreset(
    'divineRuby',
    Color(0xFF200B0D),     // Fundo vermelho escuro profundo
    Color(0xFFFFEBEE),     // Texto rosé muito claro
    Color(0xFFC62828),     // Primary rubi intenso
    Color(0xFFE57373),     // Secondary vermelho claro
    Color(0xFF3C1A1E),     // Surface vinho
  ),
  
  // 9. Cobre Vintage
  AppThemePreset(
    'vintageCopper',
    Color(0xFF3B2416),     // Fundo cobre escuro
    Color(0xFFFFF3E0),     // Texto bege claro
    Color(0xFFB87333),     // Primary cobre metálico
    Color(0xFFEF6C00),     // Secondary laranja queimado
    Color(0xFF5D3426),     // Surface marrom cobre claro
  ),
  
  // 10. Safira Celestial
  AppThemePreset(
    'celestialSapphire',
    Color(0xFF0A192F),     // Fundo azul noite profundo
    Color(0xFFBBDEFB),     // Texto azul claro
    Color(0xFF1565C0),     // Primary azul safira
    Color(0xFF64B5F6),     // Secondary azul céu
    Color(0xFF1B2951),     // Surface azul médio
  ),
  
  // 11. Ametista Mística
  AppThemePreset(
    'mysticAmethyst',
    Color(0xFF160B24),     // Fundo roxo quase preto
    Color(0xFFEDE7F6),     // Texto lilás bem claro
    Color(0xFF512DA8),     // Primary ametista forte
    Color(0xFF9575CD),     // Secondary roxo suave
    Color(0xFF2E1B47),     // Surface roxo médio
  ),
];

List<AppThemePreset> getAvailableThemes(bool isPremium) {
  return isPremium
      ? [...bibleFreeThemes, ...biblePremiumThemes]
      : bibleFreeThemes;
}

bool isThemePremium(int index) {
  return index >= bibleFreeThemes.length;
}

AppThemePreset? getThemeByIndex(int index, bool isPremium) {
  final availableThemes = getAvailableThemes(isPremium);
  if (index >= 0 && index < availableThemes.length) {
    return availableThemes[index];
  }
  return null;
}

AppThemePreset get defaultTheme => bibleFreeThemes[0];
