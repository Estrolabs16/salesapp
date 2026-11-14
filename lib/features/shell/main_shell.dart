import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/cart_controller.dart';
import '../../state/shop_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../more/more_screen.dart';
import '../pos/pos_screen.dart';
import '../sales/sales_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final CartController _cart;
  late final ShopController _shopController;

  @override
  void initState() {
    super.initState();
    _shopController = context.read<ShopController>();
    _cart = CartController(taxRate: _shopController.shop?.taxRate ?? 0);
    _shopController.addListener(_syncTaxRate);
  }

  @override
  void dispose() {
    _shopController.removeListener(_syncTaxRate);
    _cart.dispose();
    super.dispose();
  }

  void _syncTaxRate() {
    final rate = _shopController.shop?.taxRate ?? 0;
    if (_cart.taxRate != rate) _cart.setTaxRate(rate);
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CartController>.value(
      value: _cart,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              onOpenPos: () => _goTo(1),
              onOpenInventory: () => _goTo(2),
              onOpenSales: () => _goTo(3),
              onOpenMore: () => _goTo(4),
            ),
            const PosScreen(),
            const InventoryScreen(),
            const SalesScreen(),
            const MoreScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: 'Sell',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stock',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Sales',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
