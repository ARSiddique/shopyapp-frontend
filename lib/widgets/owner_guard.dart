// Small reusable guard widget to render UI only for Owner
// Place this file at: lib/widgets/owner_guard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../providers/app_data_provider_extensions.dart';

class OwnerOnly extends StatelessWidget {
  final Widget child;
  const OwnerOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (_, app, __) => app.isOwnerX ? child : const SizedBox.shrink(),
    );
  }
}
