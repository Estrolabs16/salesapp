import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/services/firestore_service.dart';
import '../../state/auth_controller.dart';
import '../../state/shop_controller.dart';
import '../auth/auth_gate.dart';
import '../setup/shop_setup_screen.dart';
import 'main_shell.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final FirestoreService _db;
  late final ShopController _shopController;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthController>().user?.uid ?? '';
    _db = FirestoreService(uid: uid);
    _shopController = ShopController(_db);
  }

  @override
  void dispose() {
    _shopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>.value(value: _db),
        ChangeNotifierProvider<ShopController>.value(value: _shopController),
      ],
      child: const _ShopGate(),
    );
  }
}

class _ShopGate extends StatelessWidget {
  const _ShopGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopController>(
      builder: (context, controller, _) {
        if (controller.loading) {
          return const BrandedSplash(message: 'Loading your shop…');
        }
        if (controller.error != null) {
          return Theme(
            data: AppTheme.light(),
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ErrorView(
                        message: controller.error!,
                        onRetry: controller.retry,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: TextButton.icon(
                        onPressed: () =>
                            context.read<AuthController>().signOut(),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final shop = controller.shop;
        if (shop == null || !shop.setupComplete) {
          return const ShopSetupScreen();
        }
        return const MainShell();
      },
    );
  }
}
