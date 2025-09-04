
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';

class NetworkGroup extends StatelessWidget {
  const NetworkGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildGroupContainer(
      context,
      title: 'Network',
      children: [
        _buildListTile(
          context,
          title: 'Active Network',
          trailing: 'Digital Rupiah Network - Private', // Example value
          onTap: () {
            // TODO: Show network list or details
          },
        ),
        _buildListTile(
          context,
          title: 'Add Network',
          onTap: () {
            // TODO: Navigate to Add Network screen
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

  Widget _buildListTile(BuildContext context, {required String title, String? trailing, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing != null
          ? Text(trailing, style: const TextStyle(color: Colors.white70))
          : const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }
}
