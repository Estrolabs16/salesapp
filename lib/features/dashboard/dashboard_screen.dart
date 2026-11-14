import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import '../customers/customers_screen.dart';
import '../inventory/product_form_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/sale_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenPos,
    required this.onOpenInventory,
    required this.onOpenSales,
    required this.onOpenMore,
  });

  final VoidCallback onOpenPos;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    if (shop == null) return const SizedBox.shrink();
    final db = context.read<FirestoreService>();
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _DashboardHeader(shop: shop, onAvatarTap: onOpenMore),
          const SizedBox(height: 20),
          StreamBuilder<List<Sale>>(
            stream: db.watchSales(
              start: startOfDay(now),
              end: endOfDay(now),
            ),
            builder: (context, snapshot) {
              final sales = (snapshot.data ?? const <Sale>[])
                  .where((sale) => !sale.isVoided)
                  .toList();
              final revenue = sales.fold<double>(
                0,
                (sum, sale) => sum + sale.total,
              );
              final profit = sales.fold<double>(
                0,
                (sum, sale) => sum + sale.grossProfit,
              );
              return _RevenueCard(
                shop: shop,
                revenue: revenue,
                profit: profit,
                saleCount: sales.length,
                loading: snapshot.connectionState == ConnectionState.waiting,
                onTap: onOpenPos,
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.point_of_sale_rounded,
                  label: 'New sale',
                  onTap: onOpenPos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_box_outlined,
                  label: 'Add product',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProductFormScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.people_alt_outlined,
                  label: 'Customers',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomersScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Low stock',
            subtitle: 'Products that need a restock',
            actionLabel: 'View stock',
            onAction: onOpenInventory,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Product>>(
            stream: db.watchProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SurfaceCard(
                  child: LoadingView(message: 'Checking stock…'),
                );
              }
              final low = (snapshot.data ?? const <Product>[])
                  .where((product) => product.active && product.isLowStock)
                  .take(3)
                  .toList();
              if (low.isEmpty) {
                return SurfaceCard(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppPalette.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppPalette.emerald,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Everything looks stocked. Add products to start selling.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < low.length; i++) ...[
                      _LowStockTile(product: low[i], onTap: onOpenInventory),
                      if (i != low.length - 1)
                        const Divider(height: 1, indent: 70),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Recent sales',
            subtitle: 'Your latest transactions',
            actionLabel: 'See all',
            onAction: onOpenSales,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Sale>>(
            stream: db.watchSales(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SurfaceCard(
                  child: LoadingView(message: 'Loading sales…'),
                );
              }
              final sales = snapshot.data ?? const <Sale>[];
              if (sales.isEmpty) {
                return SurfaceCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No sales yet',
                    message:
                        'Your first sale will appear here. Open the register to get started.',
                    actionLabel: 'Open register',
                    onAction: onOpenPos,
                  ),
                );
              }
              return SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < sales.length; i++) ...[
                      _RecentSaleTile(
                        sale: sales[i],
                        shop: shop,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SaleDetailScreen(sale: sales[i]),
                          ),
                        ),
                      ),
                      if (i != sales.length - 1)
                        const Divider(height: 1, indent: 70),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.shop, required this.onAvatarTap});

  final Shop shop;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppPalette.charcoal,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.emerald.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.all(9),
          child: const BrandMark(size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Text(
                shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CustomersScreen(),
            ),
          ),
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search customers',
        ),
        GestureDetector(
          onTap: onAvatarTap,
          child: AvatarBubble(
            label: initialsFor(
              shop.ownerName.isEmpty ? shop.name : shop.ownerName,
            ),
            size: 42,
          ),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.shop,
    required this.revenue,
    required this.profit,
    required this.saleCount,
    required this.loading,
    required this.onTap,
  });

  final Shop shop;
  final double revenue;
  final double profit;
  final int saleCount;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final revenueText = loading
        ? '—'
        : formatMoney(revenue, symbol: shop.symbol, decimals: shop.decimals);
    final profitText = loading
        ? '—'
        : formatMoneyCompact(profit, symbol: shop.symbol);
    return SurfaceCard(
      onTap: onTap,
      borderColor: AppPalette.emerald.withValues(alpha: 0.35),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123A2C), Color(0xFF07120D)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "TODAY'S REVENUE",
                style: TextStyle(
                  color: AppPalette.mint.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatDate(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              revenueText,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MiniMetric(label: 'Profit', value: profitText),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              _MiniMetric(
                label: 'Sales',
                value: loading ? '—' : '$saleCount',
              ),
              const Spacer(),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  color: AppPalette.mint,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppPalette.emerald, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: AvatarBubble(label: initialsFor(product.name), size: 40),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        product.category.isEmpty
            ? '${product.stock} left'
            : '${product.stock} left · ${product.category}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: StatusBadge(
        label: product.isOutOfStock ? 'Out' : 'Low',
        color: product.isOutOfStock ? AppPalette.danger : AppPalette.warning,
        icon: Icons.warning_amber_rounded,
      ),
    );
  }
}

class _RecentSaleTile extends StatelessWidget {
  const _RecentSaleTile({
    required this.sale,
    required this.shop,
    required this.onTap,
  });

  final Sale sale;
  final Shop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (sale.isVoided ? AppPalette.danger : AppPalette.emerald)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          sale.isVoided ? Icons.undo_rounded : Icons.receipt_long_rounded,
          color: sale.isVoided ? AppPalette.danger : AppPalette.emerald,
          size: 19,
        ),
      ),
      title: Text(
        sale.number,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        sale.customerName.isEmpty
            ? '${sale.paymentMethod} · ${sale.itemCount} items'
            : '${sale.customerName} · ${sale.paymentMethod}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(
              sale.total,
              symbol: shop.symbol,
              decimals: shop.decimals,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              decoration: sale.isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatDateTime(sale.createdAt).split(',').last.trim(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
