
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

class GeneralGroup extends StatelessWidget {
  const GeneralGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildGroupContainer(
      context,
      title: 'General & Help',
      children: [
        _buildListTile(
          context,
          title: 'About App',
          onTap: () {
            // TODO: Navigate to About App screen
          },
        ),
        _buildListTile(
          context,
          title: 'Help Center / Support',
          onTap: () {
            // TODO: Open help center URL
          },
        ),
      ],
    );
  }

  Widget _buildGroupContainer(BuildContext context, {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }
}
