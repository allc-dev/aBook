import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../database/bible_database_manager.dart';
import '../services/bible_settings_service.dart';

/// Widget para seleção da versão da Bíblia nas configurações
class BibleVersionSelector extends StatefulWidget {
  const BibleVersionSelector({Key? key}) : super(key: key);

  @override
  State<BibleVersionSelector> createState() => _BibleVersionSelectorState();
}

class _BibleVersionSelectorState extends State<BibleVersionSelector> {
  String? _currentVersion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await BibleSettingsService().getCurrentBibleVersion();
      if (!mounted) return;
      setState(() {
        _currentVersion = version;
        _loading = false;
      });
    } catch (e) {
      print('Erro ao carregar versão atual: $e');
      if (!mounted) return;
      setState(() {
        _currentVersion = 'NVI';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        if (_loading) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 8),
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
                    child: const Icon(Icons.book, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Versão da Bíblia',
                          style: TextStyle(
                            color: themeManager.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Carregando...',
                          style: TextStyle(color: themeManager.secondaryTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final versionData = BibleDatabaseManager.AVAILABLE_VERSIONS.firstWhere(
          (v) => v['code'] == _currentVersion,
          orElse: () => BibleDatabaseManager.AVAILABLE_VERSIONS.first,
        );

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _showBibleVersionDialog(context, themeManager),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.book, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Versão da Bíblia',
                          style: TextStyle(
                            color: themeManager.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${versionData['code']} • ${versionData['name']}',
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

  void _showBibleVersionDialog(BuildContext context, ThemeManager themeManager) {
    showDialog(
      context: context,
      builder: (context) => BibleVersionDialog(
        currentVersion: _currentVersion!,
        onVersionChanged: (newVersion) {
          if (!mounted) return;
          setState(() {
            _currentVersion = newVersion;
          });
        },
      ),
    );
  }
}

/// Dialog para seleção da versão da Bíblia
class BibleVersionDialog extends StatefulWidget {
  final String currentVersion;
  final Function(String) onVersionChanged;

  const BibleVersionDialog({
    Key? key,
    required this.currentVersion,
    required this.onVersionChanged,
  }) : super(key: key);

  @override
  State<BibleVersionDialog> createState() => _BibleVersionDialogState();
}

class _BibleVersionDialogState extends State<BibleVersionDialog> {
  late String _selectedVersion;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.currentVersion;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
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
                        'Escolha a versão da Bíblia',
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
                  'Sua progressão será mantida independente da versão escolhida',
                  style: TextStyle(
                    color: themeManager.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Lista de versões
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: BibleDatabaseManager.AVAILABLE_VERSIONS.map((version) {
                        final isSelected = _selectedVersion == version['code'];
                        return _buildVersionOption(
                          themeManager,
                          version['code']!,
                          version['name']!,
                          isSelected,
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
                        onPressed: _loading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: themeManager.secondaryTextColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeManager.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionOption(ThemeManager themeManager, String code, String name, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedVersion = code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? themeManager.primaryColor.withOpacity(0.1) : themeManager.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? themeManager.primaryColor : themeManager.cardColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? themeManager.primaryColor : themeManager.cardColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  code,
                  style: TextStyle(
                    color: isSelected ? Colors.white : themeManager.primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
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
                    code,
                    style: TextStyle(
                      color: isSelected ? themeManager.primaryColor : themeManager.primaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
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
                color: themeManager.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSelection() async {
    setState(() => _loading = true);
    
    try {
      await BibleSettingsService().setBibleVersion(_selectedVersion);
      
      widget.onVersionChanged(_selectedVersion);
      
      if (mounted) {
        Navigator.of(context).pop();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Versão alterada para $_selectedVersion'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar versão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
