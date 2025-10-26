import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../services/purchase_service.dart';
import 'pro_upgrade_dialog.dart';

class ThemeSelectorWidget extends StatelessWidget {
  const ThemeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final themes = themeManager.allThemes;
        final selectedIndex = themeManager.currentThemeIndex;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final theme = themes[index];
            final isSelected = selectedIndex == index;
            final isPremium = themeManager.isThemePremium(index);
            final themeName = themeManager.getThemeName(theme.labelKey);

            return GestureDetector(
              onTap: () async {
                if (isPremium && !themeManager.isPremium) {
                  await showDialog(
                    context: context,
                    builder: (_) => const ProUpgradeDialog(),
                  );
                  final ps = context.read<PurchaseService>();
                  if (ps.isProVersion) {
                    await themeManager.setPremiumStatus(true);
                    try {
                      await themeManager.setTheme(index);
                    } catch (_) {}
                  }
                  return;
                }
                try {
                  await themeManager.setTheme(index);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao aplicar tema: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? theme.primary.withOpacity(0.8) 
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: theme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    if (isPremium)
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Opacity(
                  opacity: (isPremium && !themeManager.isPremium) ? 0.6 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.background,
                          theme.background.withOpacity(0.95),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        // Conteúdo principal
                        Row(
                          children: [
                            // Indicador de cores do tema
                            Container(
                              width: 32,
                              height: 32,
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
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Nome e descrição
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    themeName,
                                    style: TextStyle(
                                      color: theme.font,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getThemeDescription(themeName),
                                    style: TextStyle(
                                      color: theme.font.withOpacity(0.6),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Indicadores superiores
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPremium)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.amber, Colors.orange],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isPremium && isSelected) const SizedBox(width: 3),
                              if (isSelected)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.primary.withOpacity(0.3),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
