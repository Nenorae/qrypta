
import 'package:flutter/material.dart';
import 'package:qrypta/src/core/config/theme/app_colors.dart';
import 'package:qrypta/src/features/profile/presentation/widgets/account_management_group.dart';
import 'package:qrypta/src/features/profile/presentation/widgets/general_group.dart';
import 'package:qrypta/src/features/profile/presentation/widgets/network_group.dart';
import 'package:qrypta/src/features/profile/presentation/widgets/security_group.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          SecurityGroup(),
          SizedBox(height: 24),
          AccountManagementGroup(),
          SizedBox(height: 24),
          NetworkGroup(),
          SizedBox(height: 24),
          GeneralGroup(),
        ],
      ),
    );
  }
}
