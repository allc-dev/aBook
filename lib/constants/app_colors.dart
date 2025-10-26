import 'package:flutter/material.dart';

class AppColors {
  // Cores principais - mantidas para compatibilidade
  static const Color primary = Color(0xFF2E7D32); // Verde bíblico
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryDark = Color(0xFF1B5E20);
  
  // Cores secundárias
  static const Color secondary = Color(0xFFFFB74D); // Dourado
  static const Color secondaryLight = Color(0xFFFFCC80);
  static const Color secondaryDark = Color(0xFFF57C00);
  
  // Níveis de dificuldade
  static const Color difficultyEasy = Color(0xFF4CAF50); // Verde
  static const Color difficultyMedium = Color(0xFFFF9800); // Laranja
  static const Color difficultyHard = Color(0xFFF44336); // Vermelho
  
  // Cores de estado
  static const Color correct = Color(0xFF4CAF50);
  static const Color incorrect = Color(0xFFF44336);
  static const Color neutral = Color(0xFF757575);
  
  // Cores de fundo
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  
  // Texto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;
  
  // Cartões e bordas
  static const Color cardBorder = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Estatísticas
  static const Color statsGreen = Color(0xFF4CAF50);
  static const Color statsBlue = Color(0xFF2196F3);
  static const Color statsOrange = Color(0xFFFF9800);
  static const Color statsRed = Color(0xFFF44336);

  // Temas bíblicos específicos - cores inspiradas na temática religiosa
  static const Map<String, Color> biblicalThemes = {
    // Cores da Terra Santa
    'jerusalemStone': Color(0xFFF5E6D3),
    'oliveBranch': Color(0xFF8D9440),
    'desertSand': Color(0xFFDEB887),
    'deadSeaBlue': Color(0xFF4682B4),
    
    // Cores litúrgicas
    'liturgicalPurple': Color(0xFF663399),
    'liturgicalGold': Color(0xFFFFD700),
    'liturgicalWhite': Color(0xFFFFFFF0),
    'liturgicalRed': Color(0xFFDC143C),
    'liturgicalGreen': Color(0xFF228B22),
    
    // Cores dos pergaminhos antigos
    'papyrus': Color(0xFFF7E7CE),
    'inkBrown': Color(0xFF3E2723),
    'copperText': Color(0xFFB87333),
    'fadeGold': Color(0xFFDAA520),
    
    // Cores místicas
    'sacredBlue': Color(0xFF191970),
    'angelicWhite': Color(0xFFFFFAFA),
    'holyFire': Color(0xFFFF6347),
    'peaceDove': Color(0xFFE6E6FA),
  };

  // Método para obter cor por nome do tema bíblico
  static Color getBiblicalColor(String colorName) {
    return biblicalThemes[colorName] ?? primary;
  }

  // Paletas temáticas pré-definidas para diferentes momentos do app
  static const Map<String, List<Color>> thematicPalettes = {
    'creation': [
      Color(0xFF87CEEB), // Céu
      Color(0xFF228B22), // Terra
      Color(0xFFFFD700), // Sol
      Color(0xFFC0C0C0), // Lua
    ],
    'exodus': [
      Color(0xFFDEB887), // Deserto
      Color(0xFF8B4513), // Terra seca
      Color(0xFF4169E1), // Mar dividido
      Color(0xFFFFFFFF), // Nuvem divina
    ],
    'wisdom': [
      Color(0xFF191970), // Azul profundo da sabedoria
      Color(0xFFFFD700), // Dourado da iluminação
      Color(0xFF4B0082), // Índigo da meditação
      Color(0xFFF5F5DC), // Bege do pergaminho
    ],
    'psalms': [
      Color(0xFF708090), // Cinza pedra
      Color(0xFF98FB98), // Verde pasto
      Color(0xFF87CEEB), // Azul águas tranquilas
      Color(0xFFFFE4B5), // Dourado suave
    ],
  };

  // Método para obter paleta temática
  static List<Color> getThematicPalette(String paletteName) {
    return thematicPalettes[paletteName] ?? [primary, secondary, background, surface];
  }
}
