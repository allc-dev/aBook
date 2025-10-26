import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import 'main_navigation_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: themeManager.backgroundColor,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ícone removido para ganhar mais espaço no topo
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.appName,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontFamily: 'Roboto',
                              ) ?? TextStyle(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        // const SizedBox(height: 10),
                        // Text(
                        //   'Quiz Bíblico Interativo',
                        //   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        //         color: themeManager.secondaryTextColor,
                        //         fontWeight: FontWeight.w500,
                        //         fontFamily: 'Roboto',
                        //       ) ?? TextStyle(
                        //         color: themeManager.secondaryTextColor,
                        //         fontWeight: FontWeight.w500,
                        //         fontSize: 20,
                        //       ),
                        //   textAlign: TextAlign.center,
                        // ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: themeManager.surfaceColor,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: themeManager.cardColor.withOpacity(0.22)),
                            boxShadow: [
                              BoxShadow(
                                color: themeManager.primaryColor.withOpacity(0.07),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Vamos começar!',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: themeManager.primaryTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        fontFamily: 'Roboto',
                                      ) ?? TextStyle(
                                        color: themeManager.primaryTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Como você gostaria de ser chamado?',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: themeManager.secondaryTextColor,
                                        fontSize: 16,
                                        fontFamily: 'Roboto',
                                      ) ?? TextStyle(
                                        color: themeManager.secondaryTextColor,
                                        fontSize: 16,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 28),
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'Seu nome',
                                    hintText: 'Digite aqui...',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: themeManager.primaryColor,
                                      size: 22,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: themeManager.cardColor.withOpacity(0.22)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: themeManager.primaryColor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: themeManager.backgroundColor,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                  ),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: themeManager.primaryTextColor,
                                    fontFamily: 'Roboto',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Por favor, digite seu nome';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Nome deve ter pelo menos 2 caracteres';
                                    }
                                    if (value.trim().length > 20) {
                                      return 'Nome deve ter no máximo 20 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeManager.primaryColor,
                                    foregroundColor: themeManager.primaryTextColor,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(themeManager.primaryTextColor),
                                          ),
                                        )
                                      : const Text('Começar a Jogar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final gameProvider = context.read<GameProvider>();
      
      // Salvar o nome do jogador
      await gameProvider.setPlayerName(name);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
