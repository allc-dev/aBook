import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/purchase_service.dart';
import '../services/themes/theme_manager.dart';

class ProUpgradeDialog extends StatelessWidget {
  const ProUpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeManager>(context);
    return Consumer<PurchaseService>(
      builder: (context, purchaseService, child) {
        final product = purchaseService.getProVersionProduct();
        final priceLabel = product?.price ?? 'R\$ 4,99';

        // Fecha automaticamente se virar PRO
        if (purchaseService.isProVersion) {
          Future.microtask(() => Navigator.of(context).maybePop());
        }

        return AlertDialog(
          backgroundColor: theme.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.only(left: 24, right: 8, top: 12, bottom: 0),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Atualizar para PRO',
                  style: TextStyle(
                    color: theme.primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Desbloqueie recursos exclusivos e remova os anúncios!',
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _feature(theme, Icons.block, 'Sem Anúncios'),
                _feature(theme, Icons.palette, 'Temas Exclusivos'),
                _feature(theme, Icons.support, 'Apoie o Desenvolvedor'),
                if (purchaseService.purchaseError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            purchaseService.purchaseError,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Botões centralizados na horizontal, largura igual, espaçamento igual
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (_) {
                          if (!purchaseService.isAvailable) {
                            return SizedBox(
                              width: 220,
                              child: TextButton(
                                onPressed: null,
                                child: Text('Indisponível', style: TextStyle(color: theme.mutedTextColor)),
                              ),
                            );
                          }
                          if (purchaseService.isPurchasing) {
                            return SizedBox(
                              width: 220,
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Processando...', style: TextStyle(color: theme.primaryColor)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (purchaseService.isAvailable && !purchaseService.isPurchasing) ...[
                        SizedBox(
                          width: 220,
                          child: TextButton(
                            onPressed: () => purchaseService.buyProVersion(),
                            child: Text('Comprar por $priceLabel', style: TextStyle(color: theme.primaryColor)),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.primaryColor,
                              minimumSize: const Size(160, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      SizedBox(
                        width: 220,
                        child: TextButton(
                          onPressed: purchaseService.isPurchasing ? null : () async {
                            final uri = Uri.parse('https://wa.me/5512988543055?text=Ol%C3%A1!%20Quero%20o%20c%C3%B3digo%20gr%C3%A1tis%20da%20Vers%C3%A3o%20Pro%20do%20Qual%20%C3%A9%20o%20Livro.');
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          child: Text('Pedir código grátis', style: TextStyle(color: theme.primaryColor)),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            minimumSize: const Size(160, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 220,
                        child: TextButton(
                          onPressed: purchaseService.isPurchasing ? null : () => purchaseService.restorePurchases(),
                          child: Text('Restaurar Compras', style: TextStyle(color: theme.primaryColor)),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            minimumSize: const Size(160, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _feature(ThemeManager theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Icon(icon, color: theme.primaryTextColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: theme.primaryTextColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
