import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';


void showAppAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      Widget buildContactButton(
          IconData icon, String label, VoidCallback onPressed) {
        return InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }

      final colorScheme = Theme.of(context).colorScheme;
      final dialogBackgroundColor = colorScheme.surface;
      final textColor = colorScheme.onSurface;

  // final locale = Localizations.localeOf(context);
  // final isBrazil = (locale.languageCode == 'pt') &&
  //     (locale.countryCode?.toUpperCase() == 'BR' || locale.countryCode == null);

      return AlertDialog(
        backgroundColor: dialogBackgroundColor,
        title: GestureDetector(
          child: Text('Sobre', style: TextStyle(color: textColor)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Contato e Links:',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildContactButton(Icons.code, 'GitHub',
                      () => _launchURL('https://github.com/andrellopes/aBook')),
                  buildContactButton(Icons.email_outlined, 'Email',
                      () => _launchURL('mailto:allc.dev@hotmail.com')),
                  buildContactButton(Icons.chat_bubble_outline, 'WhatsApp',
                      () => _launchURL('https://wa.me/5512988543055')),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Se este aplicativo foi útil para você,\nconsidere apoiar o desenvolvimento com um café ☕!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Fechar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton.icon(
            onPressed: () {
              const pixKey = 'allc.dev@hotmail.com';
              Clipboard.setData(const ClipboardData(text: pixKey));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chave PIX copiada!'),
                ),
              );
            },
            icon: const Icon(Icons.pix),
            label: const Text('Apoiar com PIX'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32BCAD),
                foregroundColor: Colors.white),
          ),
          // PayPal removido para público brasileiro
          // ElevatedButton.icon(
          //   onPressed: () {
          //     _launchURL(
          //       'https://www.paypal.com/donate/?business=4BEH3GPHPRVFY'
          //       '&no_recurring=0'
          //       '&item_name=Thank+you+for+using+the+app%21+If+you%27d+like+to+support+this+independent+project%2C+any+contribution+is+welcome+%F0%9F%92%99'
          //       '&currency_code=USD',
          //     );
          //   },
          //   icon: const Icon(Icons.payment),
          //   label: const Text("PayPal"),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.blueAccent,
          //     foregroundColor: Colors.white,
          //   ),
          // ),
        ],
      );
    },
  );
}

Future<void> _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint("Não foi possível abrir $url");
  }
}
