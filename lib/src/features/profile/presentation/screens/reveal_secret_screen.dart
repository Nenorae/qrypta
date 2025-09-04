import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

// New: Enum to differentiate between secret types
enum SecretType {
  mnemonic,
  privateKey,
}

class RevealSecretScreen extends StatelessWidget {
  final String title;
  final String secretData;
  final String warningText;
  final SecretType type; // New: Add type parameter

  const RevealSecretScreen({
    super.key,
    required this.title,
    required this.secretData,
    required this.warningText,
    required this.type, // New: Require type in constructor
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: AppColors.font)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.font),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Box (remains the same)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      warningText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Modified: Use a helper to build the correct display
            _buildSecretDisplay(context),

            const Spacer(),

            // Copy to Clipboard Button (remains the same)
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('COPY TO CLIPBOARD'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: secretData));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title copied to clipboard!'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New: Helper widget to conditionally display the secret
  Widget _buildSecretDisplay(BuildContext context) {
    // If it's a private key, show a simple selectable text box.
    if (type == SecretType.privateKey) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          secretData,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'monospace', // Use a monospace font for keys
          ),
        ),
      );
    }

    // Otherwise (it's a mnemonic), show the grid view.
    final secretWords = secretData.split(' ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: secretWords.length,
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              '${index + 1}. ${secretWords[index]}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        },
      ),
    );
  }
}
