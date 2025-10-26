import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/themes/theme_manager.dart';
import 'package:provider/provider.dart';

class DatabaseInitializationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const DatabaseInitializationScreen({super.key, required this.onComplete});

  @override
  State<DatabaseInitializationScreen> createState() => _DatabaseInitializationScreenState();
}

class _DatabaseInitializationScreenState extends State<DatabaseInitializationScreen>
    with SingleTickerProviderStateMixin {
  
  String _currentMessage = 'Preparando sistema...';
  double _progress = 0.0;
  bool _isComplete = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _initializeDatabase();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    try {
      await DatabaseHelper().initialize(
        onProgress: (message, progress) {
          if (mounted) {
            setState(() {
              _currentMessage = message;
              _progress = progress;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentMessage = 'Concluído!';
          _progress = 1.0;
        });
        
        // Aguardar um pouco para mostrar a conclusão
        await Future.delayed(const Duration(milliseconds: 800));
        
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentMessage = 'Erro na inicialização: $e';
          _progress = 0.0;
        });
        
        // Mostrar erro por um tempo e tentar novamente
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _initializeDatabase(); // Tentar novamente
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    
    return Scaffold(
      backgroundColor: themeManager.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone da Bíblia
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: themeManager.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: themeManager.primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 60,
                    color: themeManager.primaryColor,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Título
                Text(
                  'BookQuest',
                  style: TextStyle(
                    color: themeManager.primaryTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Preparando sua experiência bíblica...',
                  style: TextStyle(
                    color: themeManager.secondaryTextColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // Indicador de progresso
                Container(
                  width: 280,
                  height: 6,
                  decoration: BoxDecoration(
                    color: themeManager.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 280 * _progress,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isComplete 
                              ? Colors.green 
                              : themeManager.primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Mensagem de status
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _currentMessage,
                      key: ValueKey(_currentMessage),
                      style: TextStyle(
                        color: themeManager.primaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Indicador de carregamento adicional (apenas se não estiver completo)
                if (!_isComplete)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeManager.primaryColor,
                      ),
                    ),
                  ),
                
                if (_isComplete)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                
                const SizedBox(height: 48),
                
                // Texto explicativo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Este processo acontece apenas na primeira vez.\nEstamos preparando as versões da Bíblia e configurando o sistema de quiz.',
                    style: TextStyle(
                      color: themeManager.secondaryTextColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
