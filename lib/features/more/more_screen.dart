import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/export.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/auth_controller.dart';
import '../../state/shop_controller.dart';
import '../auth/register_screen.dart';
import '../customers/customers_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/reports_screen.dart';
import '../setup/shop_setup_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final auth = context.read<AuthController>();
    if (shop == null) return const SizedBox.shrink();
    final user = auth.user;
    final isGuest = user?.isAnonymous ?? false;
    final verified = user?.emailVerified ?? false;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text(
            'More',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Your account, shop and data.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            borderColor: AppPalette.emerald.withValues(alpha: 0.3),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123A2C), Color(0xFF07120D)],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const BrandHeroMark(size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shop.ownerName.isEmpty ? 'Shop owner' : shop.ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isGuest ? 'Guest mode · this device' : (user?.email ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.mint.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShopSetupScreen(editing: true),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit shop profile',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Manage'),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MenuTile(
                icon: Icons.people_alt_outlined,
                title: 'Customers',
                subtitle: 'Contacts, spend and visit history',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomersScreen(),
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.receipt_outlined,
                title: 'Expenses',
                subtitle: 'Track rent, supplies and running costs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExpensesScreen(),
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.bar_chart_rounded,
                title: 'Reports',
                subtitle: 'Revenue, profit and best sellers',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.storefront_outlined,
                title: 'Shop profile',
                subtitle: 'Name, currency, tax and stock alerts',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShopSetupScreen(editing: true),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Data'),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MenuTile(
                icon: Icons.inventory_2_outlined,
                title: 'Export inventory',
                subtitle: 'Share a CSV of all products and stock',
                trailing: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _busy ? null : () => _exportInventory(shop),
              ),
              _MenuTile(
                icon: Icons.file_download_outlined,
                title: 'Export sales',
                subtitle: 'Share up to 1,000 recent sales as CSV',
                onTap: _busy ? null : () => _exportSales(shop),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupLabel('Account'),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              if (isGuest)
                _MenuTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Create an account',
                  subtitle: 'Keep your data — add an email & password',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                ),
              if (!isGuest)
                _MenuTile(
                  icon: verified
                      ? Icons.verified_outlined
                      : Icons.mark_email_unread_outlined,
                  title: verified ? 'Email verified' : 'Verify your email',
                  subtitle: verified
                      ? user?.email ?? ''
                      : 'Send a verification link to ${user?.email ?? 'your inbox'}',
                  trailing: verified
                      ? const StatusBadge(
                          label: 'Verified',
                          color: AppPalette.emerald,
                        )
                      : null,
                  onTap: verified ? null : _sendVerification,
                ),
              _MenuTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'Securely end this session',
                danger: true,
                onTap: _signOut,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupLabel('About'),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MenuTile(
                icon: Icons.info_outline_rounded,
                title: 'About EstroShop',
                subtitle: 'Version 1.1.0 · Business, in control.',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'EstroShop',
                  applicationVersion: '1.1.0',
                  applicationIcon: const BrandHeroMark(size: 48),
                  applicationLegalese:
                      '© ${DateTime.now().year} EstroShop. Built for everyday businesses.',
                ),
              ),
              const _MenuTile(
                icon: Icons.light_mode_outlined,
                title: 'Appearance',
                subtitle: 'Always light — easy to read in any store',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'EstroShop · Sell. Track. Grow.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportInventory(Shop shop) async {
    setState(() => _busy = true);
    try {
      final products = await context.read<FirestoreService>().watchProducts().first;
      if (products.isEmpty) {
        if (mounted) showAppSnack(context, 'No products to export yet.');
        return;
      }
      final csv = CsvBuilder([
        'Name',
        'SKU',
        'Category',
        'Cost price',
        'Selling price',
        'Stock',
        'Low stock threshold',
        'Status',
        'Stock value',
      ]);
      for (final product in products) {
        csv.addRow([
          product.name,
          product.sku,
          product.category,
          product.costPrice.toStringAsFixed(shop.decimals),
          product.sellingPrice.toStringAsFixed(shop.decimals),
          product.stock,
          product.lowStockThreshold,
          product.active ? 'Active' : 'Hidden',
          product.stockValue.toStringAsFixed(shop.decimals),
        ]);
      }
      final stamp = formatDate(DateTime.now()).replaceAll(' ', '-');
      await shareCsvFile(
        fileName: 'estroshop-inventory-$stamp.csv',
        content: csv.build(),
        subject: 'EstroShop inventory export',
      );
      await AppAnalytics.logExport(type: 'inventory');
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSales(Shop shop) async {
    setState(() => _busy = true);
    try {
      final sales = await context.read<FirestoreService>().watchSales(
        limit: 1000,
      ).first;
      if (sales.isEmpty) {
        if (mounted) showAppSnack(context, 'No sales to export yet.');
        return;
      }
      final csv = CsvBuilder([
        'Date',
        'Receipt',
        'Customer',
        'Payment',
        'Items',
        'Total',
        'Profit',
        'Status',
      ]);
      for (final sale in sales) {
        csv.addRow([
          formatDateTime(sale.createdAt),
          sale.number,
          sale.customerName.isEmpty ? 'Walk-in customer' : sale.customerName,
          sale.paymentMethod,
          sale.itemCount,
          sale.total.toStringAsFixed(shop.decimals),
          sale.grossProfit.toStringAsFixed(shop.decimals),
          sale.isVoided ? 'Voided' : 'Completed',
        ]);
      }
      final stamp = formatDate(DateTime.now()).replaceAll(' ', '-');
      await shareCsvFile(
        fileName: 'estroshop-sales-$stamp.csv',
        content: csv.build(),
        subject: 'EstroShop sales export',
      );
      await AppAnalytics.logExport(type: 'sales');
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendVerification() async {
    try {
      await context.read<AuthController>().sendVerificationEmail();
      if (mounted) {
        showAppSnack(context, 'Verification email sent.');
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You can sign back in at any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthController>().signOut();
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.45),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 58),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = danger ? AppPalette.danger : AppPalette.emerald;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? AppPalette.danger : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}
