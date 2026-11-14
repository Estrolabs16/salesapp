import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/export.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import 'sale_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _period = 'Today';
  bool _exporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _range() {
    final now = DateTime.now();
    return switch (_period) {
      '7 days' => (startOfDay(addDays(now, -6)), endOfDay(now)),
      '30 days' => (startOfDay(addDays(now, -29)), endOfDay(now)),
      'All' => (null, null),
      _ => (startOfDay(now), endOfDay(now)),
    };
  }

  Future<void> _export(List<Sale> sales, Shop shop) async {
    if (_exporting) return;
    if (sales.isEmpty) {
      showAppSnack(context, 'No sales to export yet.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final csv = CsvBuilder([
        'Receipt',
        'Date',
        'Customer',
        'Payment',
        'Items',
        'Subtotal',
        'Discount',
        'Tax',
        'Total',
        'Profit',
        'Status',
      ]);
      for (final sale in sales) {
        csv.addRow([
          sale.number,
          formatDateTime(sale.createdAt),
          sale.customerName.isEmpty ? 'Walk-in customer' : sale.customerName,
          sale.paymentMethod,
          sale.itemCount,
          sale.subtotal.toStringAsFixed(shop.decimals),
          sale.discount.toStringAsFixed(shop.decimals),
          sale.tax.toStringAsFixed(shop.decimals),
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final db = context.read<FirestoreService>();
    if (shop == null) return const SizedBox.shrink();
    final range = _range();

    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<Sale>>(
        stream: db.watchSales(
          start: range.$1,
          end: range.$2,
          limit: 500,
        ),
        builder: (context, snapshot) {
          final sales = snapshot.data ?? const <Sale>[];
          final completed = sales.where((sale) => !sale.isVoided);
          final revenue = completed.fold<double>(
            0,
            (sum, sale) => sum + sale.total,
          );
          final profit = completed.fold<double>(
            0,
            (sum, sale) => sum + sale.grossProfit,
          );
          final query = _query.toLowerCase();
          final visible = sales.where((sale) {
            if (query.isEmpty) return true;
            return sale.number.toLowerCase().contains(query) ||
                sale.customerName.toLowerCase().contains(query) ||
                sale.paymentMethod.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Receipts, revenue and profit.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Export sales',
                      onPressed: _exporting || sales.isEmpty
                          ? null
                          : () => _export(sales, shop),
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search receipt, customer or payment',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  children: [
                    for (final period in const [
                      'Today',
                      '7 days',
                      '30 days',
                      'All',
                    ]) ...[
                      ChoiceChip(
                        label: Text(period),
                        selected: _period == period,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _period = period),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SalesStat(
                        label: 'Revenue',
                        value: formatMoneyCompact(
                          revenue,
                          symbol: shop.symbol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SalesStat(
                        label: 'Profit',
                        value: formatMoneyCompact(profit, symbol: shop.symbol),
                        accent: AppPalette.emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SalesStat(
                        label: 'Transactions',
                        value: '${completed.length}',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const LoadingView(message: 'Loading sales…')
                    : snapshot.hasError
                    ? const ErrorView(
                        message: 'Unable to load sales right now.',
                      )
                    : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: sales.isEmpty ? 'No sales yet' : 'No matches',
                        message: sales.isEmpty
                            ? 'Completed sales will appear here with receipts and profit.'
                            : 'Try another search term or period.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sale = visible[index];
                          return _SaleRow(
                            sale: sale,
                            shop: shop,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SaleDetailScreen(sale: sale),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesStat extends StatelessWidget {
  const _SalesStat({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({
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
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (sale.isVoided ? AppPalette.danger : AppPalette.emerald)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              sale.isVoided ? Icons.undo_rounded : Icons.receipt_long_rounded,
              size: 19,
              color: sale.isVoided ? AppPalette.danger : AppPalette.emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sale.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (sale.isVoided) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(
                        label: 'Voided',
                        color: AppPalette.danger,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sale.customerName.isEmpty
                      ? '${sale.paymentMethod} · ${sale.itemCount} items'
                      : '${sale.customerName} · ${sale.paymentMethod}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  formatDateTime(sale.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(
              sale.total,
              symbol: shop.symbol,
              decimals: shop.decimals,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              decoration: sale.isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
