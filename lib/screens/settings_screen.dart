import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/themes/theme_manager.dart';
import '../widgets/bible_version_selector.dart';
import '../services/purchase_service.dart';
import '../widgets/pro_upgrade_dialog.dart';
import '../providers/game_provider.dart';
import '../widgets/about_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _keepScreenOn = true;

  @override
  void initState() {
    super.initState();
    _loadKeepScreenOn();
  }

  Future<void> _loadKeepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
    });
    WakelockPlus.enable(); // Garante que a tela fique ligada por padrão
    if (_keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<void> _setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepScreenOn', value);
    setState(() {
      _keepScreenOn = value;
    });
    if (value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final isPro = Provider.of<PurchaseService>(context).isProVersion;
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Configurações',
              style: TextStyle(
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            backgroundColor: themeManager.backgroundColor,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
            ),
            iconTheme: IconThemeData(color: themeManager.primaryTextColor),
            actions: [
              if (isPro)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Seção do personagem fixo no topo
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPlayerSection(context, themeManager),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // PRO card (aparece se não for PRO)
                    if (!isPro) ...[
                      _buildProEntry(context, themeManager),
                    ],

                    // Seletor de versão da Bíblia
                    const BibleVersionSelector(),

                    // Dificuldade (abre diálogo)
                    Consumer<GameProvider>(builder: (ctx, gp, _) {
                      final current = gp.defaultDifficulty ?? 'Fácil';
                      final subtitle = '$current • ${_shortSpecFor(current)}';
                      final iconSpec = _iconSpecFor(themeManager, current);
                      return _settingsCard(
                        context,
                        themeManager: themeManager,
                        icon: iconSpec.icon,
                        color: iconSpec.color,
                        title: "Dificuldade",
                        subtitle: subtitle,
                        onTap: () async {
                          final changed = await showDialog<String?>(
                            context: context,
                            builder: (_) => const DifficultyPickerDialog(),
                          );
                          if (changed != null) {
                            await gp.setDefaultDifficulty(changed);
                          }
                        },
                      );
                    }),

                    // Tema (abre modal)
                    Consumer<ThemeManager>(builder: (ctx, tm, _) {
                      final currentTheme = tm.allThemes[tm.currentThemeIndex];
                      final themeName = tm.getThemeName(currentTheme.labelKey);
                      final isPremium = tm.isThemePremium(tm.currentThemeIndex);
                      final subtitle = isPremium ? '$themeName • PRO' : themeName;
                      
                      return _settingsCard(
                        context,
                        themeManager: themeManager,
                        icon: Icons.palette,
                        color: currentTheme.primary,
                        title: "Tema",
                        subtitle: subtitle,
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const ThemeSelectionDialog(),
                          );
                        },
                      );
                    }),

                    // Manter tela ligada
                    _settingsCard(
                      context,
                      themeManager: themeManager,
                      icon: Icons.screen_lock_portrait,
                      color: themeManager.primaryColor,
                      title: "Manter tela sempre ligada",
                      subtitle: "Evita que o celular desligue a tela",
                      trailing: Switch(
                        value: _keepScreenOn,
                        onChanged: _setKeepScreenOn,
                        activeColor: themeManager.primaryColor,
                      ),
                    ),

                    // Sobre (abre modal)
                    FutureBuilder<String>(
                      future: _getAppVersion(),
                      builder: (context, snapshot) {
                        final version = snapshot.data ?? '...';
                        return _settingsCard(
                          context,
                          themeManager: themeManager,
                          icon: Icons.info_outline,
                          color: themeManager.primaryColor,
                          title: "Sobre",
                          subtitle: "BookQuest - Quiz Bíblico • Versão $version",
                          onTap: () => _showAboutDialog(context, themeManager),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Seção do personagem (migrada do drawer)
  Widget _buildPlayerSection(BuildContext context, ThemeManager themeManager) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeManager.primaryColor,
                themeManager.primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeManager.primaryColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Informações do jogador
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                gameProvider.playerName ?? 'Jogador',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                              onPressed: () => _showEditNameDialog(context, themeManager, gameProvider),
                            ),
                          ],
                        ),
                        Text(
                          'Nível ${gameProvider.playerLevel}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Barra de progresso do nível
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progresso: ${(gameProvider.levelProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: gameProvider.levelProgress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
        );
      },
    );
  }

  // Diálogo para editar nome do jogador
  void _showEditNameDialog(BuildContext context, ThemeManager themeManager, GameProvider gameProvider) {
    final TextEditingController controller = TextEditingController(text: gameProvider.playerName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeManager.surfaceColor,
        title: Text(
          'Editar Nome',
          style: TextStyle(color: themeManager.primaryTextColor),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: themeManager.primaryTextColor),
          decoration: InputDecoration(
            labelText: 'Seu nome',
            labelStyle: TextStyle(color: themeManager.secondaryTextColor),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: themeManager.primaryColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: themeManager.primaryColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: themeManager.primaryColor),
            ),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: themeManager.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await gameProvider.setPlayerName(newName);
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeManager.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // Método para obter versão do app
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return 'Desconhecida';
    }
  }

  // Método para mostrar o diálogo Sobre
  void _showAboutDialog(BuildContext context, ThemeManager themeManager) {
    showAppAboutDialog(context);
  }

  Widget _settingsCard(
    BuildContext context, {
    required ThemeManager themeManager,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? child,
    Widget? trailing,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: themeManager.primaryTextColor,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: themeManager.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing
                  else if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: themeManager.secondaryTextColor,
                    ),
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: 16),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProEntry(BuildContext context, ThemeManager themeManager) {
    return Consumer<PurchaseService>(
      builder: (context, purchaseService, child) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const ProUpgradeDialog(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atualizar para PRO',
                          style: TextStyle(
                            color: themeManager.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sem Anúncios • Temas Exclusivos',
                          style: TextStyle(color: themeManager.secondaryTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: themeManager.secondaryTextColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== CLASSES GLOBAIS =====
// (deixe todas as classes globais e funções auxiliares abaixo deste ponto)
class DifficultyPickerDialog extends StatefulWidget {
  const DifficultyPickerDialog({super.key});

  @override
  State<DifficultyPickerDialog> createState() => _DifficultyPickerDialogState();
}

class _DifficultyPickerDialogState extends State<DifficultyPickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<GameProvider>().defaultDifficulty ?? 'Fácil';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(builder: (context, theme, _) {
      return AlertDialog(
        backgroundColor: theme.surfaceColor,
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text('Escolha a dificuldade',
                  style: TextStyle(
                      color: theme.primaryTextColor,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: theme.secondaryTextColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _difficultyTile('Fácil', theme.difficultyEasyColor, '120s • ∞ vidas'),
            _difficultyTile('Médio', theme.difficultyMediumColor, '90s • 5 vidas'),
            _difficultyTile('Difícil', theme.difficultyHardColor, '60s • 3 vidas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final gp = context.read<GameProvider>();
              await gp.setDefaultDifficulty(_selected);
              if (mounted) Navigator.of(context).pop(_selected);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected == 'Fácil'
                  ? theme.difficultyEasyColor
                  : _selected == 'Médio'
                      ? theme.difficultyMediumColor
                      : theme.difficultyHardColor,
            ),
            child: const Text('Escolher'),
          ),
        ],
      );
    });
  }

  Widget _difficultyTile(String title, Color color, String subtitle) {
    final icon = title == 'Fácil'
        ? Icons.sentiment_satisfied
        : title == 'Médio'
            ? Icons.sentiment_neutral
            : Icons.sentiment_very_dissatisfied;
    return RadioListTile<String>(
      value: title,
      activeColor: color,
      groupValue: _selected,
      onChanged: (v) => setState(() => _selected = v ?? _selected),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
      subtitle: Text(subtitle),
    );
  }
}

class ThemeSelectionDialog extends StatefulWidget {
  const ThemeSelectionDialog({super.key});

  @override
  State<ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = context.read<ThemeManager>().currentThemeIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(builder: (context, themeManager, _) {
      final themes = themeManager.allThemes;
      
      return Dialog(
        backgroundColor: themeManager.surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Escolha o tema',
                      style: TextStyle(
                        color: themeManager.primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: themeManager.secondaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Personalize a aparência do aplicativo',
                style: TextStyle(
                  color: themeManager.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              
              // Lista de temas
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: themes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final theme = entry.value;
                      final isSelected = _selectedIndex == index;
                      final isPremium = themeManager.isThemePremium(index);
                      final themeName = themeManager.getThemeName(theme.labelKey);
                      
                      return _buildThemeOption(
                        themeManager,
                        theme,
                        themeName,
                        index,
                        isSelected,
                        isPremium,
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botões
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: themeManager.secondaryTextColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _applyTheme(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themes[_selectedIndex].primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildThemeOption(
    ThemeManager themeManager,
    dynamic theme,
    String themeName,
    int index,
    bool isSelected,
    bool isPremium,
  ) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary.withOpacity(0.1) : themeManager.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primary : themeManager.cardColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Indicador visual do tema
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Fundo principal
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // Seção primária (diagonal)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ThemeColorPainter(
                        primaryColor: theme.primary,
                        secondaryColor: theme.secondary,
                        surfaceColor: theme.surface,
                      ),
                    ),
                  ),
                  // Ícone central
                  Center(
                    child: Icon(
                      Icons.palette_rounded,
                      color: theme.font.withOpacity(0.8),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        themeName,
                        style: TextStyle(
                          color: isSelected ? theme.primary : themeManager.primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getThemeDescription(themeName),
                    style: TextStyle(
                      color: themeManager.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getThemeDescription(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'pergaminho antigo':
        return 'Clássico e elegante';
      case 'clássico bíblico':
        return 'Tradicional e limpo';
      case 'noite serena':
        return 'Escuro e moderno';
      case 'azul saber':
        return 'Profissional e calmo';
      default:
        return 'Tema personalizado';
    }
  }

  Future<void> _applyTheme() async {
    final themeManager = context.read<ThemeManager>();
    final isPremium = themeManager.isThemePremium(_selectedIndex);
    
    if (isPremium && !themeManager.isPremium) {
      await showDialog(
        context: context,
        builder: (_) => const ProUpgradeDialog(),
      );
      final ps = context.read<PurchaseService>();
      if (ps.isProVersion) {
        await themeManager.setPremiumStatus(true);
        try {
          await themeManager.setTheme(_selectedIndex);
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Tema aplicado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao aplicar tema: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      return;
    }
    
    try {
      await themeManager.setTheme(_selectedIndex);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tema aplicado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar tema: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom painter para criar o indicador de cores do tema
class _ThemeColorPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  _ThemeColorPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 8.0;
    
    // Seção primária (canto superior direito)
    final primaryPath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.5, 0)
      ..close();

    canvas.drawPath(primaryPath, Paint()..color = primaryColor.withOpacity(0.8));

    // Seção secundária (canto inferior esquerdo)
    final secondaryPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(
        Offset(radius, size.height),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.5)
      ..close();

    canvas.drawPath(secondaryPath, Paint()..color = secondaryColor.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _IconSpec {
  final IconData icon;
  final Color color;
  _IconSpec(this.icon, this.color);
}

_IconSpec _iconSpecFor(ThemeManager theme, String title) {
  switch (title) {
    case 'Fácil':
      return _IconSpec(Icons.sentiment_satisfied, theme.difficultyEasyColor);
    case 'Médio':
      return _IconSpec(Icons.sentiment_neutral, theme.difficultyMediumColor);
    default:
      return _IconSpec(Icons.sentiment_very_dissatisfied, theme.difficultyHardColor);
  }
}

String _shortSpecFor(String title) {
  switch (title) {
    case 'Fácil':
      return '120s • ∞ vidas';
    case 'Médio':
      return '90s • 5 vidas';
    default:
      return '60s • 3 vidas';
  }
}