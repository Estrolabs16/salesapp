import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/export.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/expense.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'This month';
  bool _exporting = false;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    return switch (_period) {
      'Today' => (startOfDay(now), endOfDay(now)),
      'This week' => (
        startOfDay(addDays(now, -(now.weekday - 1))),
        endOfDay(now),
      ),
      'Last 30 days' => (startOfDay(addDays(now, -29)), endOfDay(now)),
      _ => (startOfMonth(now), endOfDay(now)),
    };
  }

  Future<void> _export(List<Sale> sales, Shop shop) async {
    if (_exporting) return;
    if (sales.isEmpty) {
      showAppSnack(context, 'No sales in this period.');
      return;
    }
    setState(() => _exporting = true);
    try {
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
        fileName: 'estroshop-report-$stamp.csv',
        content: csv.build(),
        subject: 'EstroShop report · $_period',
      );
      await AppAnalytics.logExport(type: 'report');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export report',
            onPressed: _exporting
                ? null
                : () async {
                    final sales = await db
                        .watchSales(start: range.$1, end: range.$2, limit: 1000)
                        .first;
                    if (mounted) _export(sales, shop);
                  },
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
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Sale>>(
          stream: db.watchSales(
            start: range.$1,
            end: range.$2,
            limit: 1000,
          ),
          builder: (context, salesSnapshot) {
            return StreamBuilder<List<Expense>>(
              stream: db.watchExpensesInRange(range.$1, range.$2),
              builder: (context, expenseSnapshot) {
                if (salesSnapshot.connectionState == ConnectionState.waiting ||
                    expenseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const LoadingView(message: 'Crunching numbers…');
                }
                if (salesSnapshot.hasError || expenseSnapshot.hasError) {
                  return const ErrorView(
                    message: 'Unable to build this report right now.',
                  );
                }
                final allSales = salesSnapshot.data ?? const <Sale>[];
                final expenses =
                    expenseSnapshot.data ?? const <Expense>[];
                final sales = allSales
                    .where((sale) => !sale.isVoided)
                    .toList();
                final revenue = sales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.total,
                );
                final grossProfit = sales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.grossProfit,
                );
                final expenseTotal = expenses.fold<double>(
                  0,
                  (sum, expense) => sum + expense.amount,
                );
                final netProfit = grossProfit - expenseTotal;
                final average = sales.isEmpty ? 0.0 : revenue / sales.length;

                final productStats = <String, _ProductStat>{};
                for (final sale in sales) {
                  for (final item in sale.items) {
                    final stat = productStats.putIfAbsent(
                      item.productId,
                      () => _ProductStat(name: item.name),
                    );
                    stat.quantity += item.quantity;
                    stat.revenue += item.lineTotal;
                  }
                }
                final topProducts = productStats.values.toList()
                  ..sort((a, b) => b.revenue.compareTo(a.revenue));

                final paymentMix = <String, double>{};
                for (final sale in sales) {
                  paymentMix.update(
                    sale.paymentMethod,
                    (value) => value + sale.total,
                    ifAbsent: () => sale.total,
                  );
                }
                final payments = paymentMix.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final buckets = _buildBuckets(
                  sales,
                  range.$1,
                  range.$2,
                  _period,
                );
                final maxBucket = buckets.fold<double>(
                  0,
                  (max, bucket) => math.max(max, bucket.value),
                );
                final maxY = maxBucket <= 0 ? 100.0 : maxBucket * 1.25;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final period in const [
                            'Today',
                            'This week',
                            'This month',
                            'Last 30 days',
                          ]) ...[
                            ChoiceChip(
                              label: Text(period),
                              selected: _period == period,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _period = period),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReportHero(
                      shop: shop,
                      revenue: revenue,
                      netProfit: netProfit,
                      expenseTotal: expenseTotal,
                      saleCount: sales.length,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Gross profit',
                            value: formatMoneyCompact(
                              grossProfit,
                              symbol: shop.symbol,
                            ),
                            icon: Icons.trending_up_rounded,
                            accent: AppPalette.emerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Average sale',
                            value: formatMoneyCompact(
                              average,
                              symbol: shop.symbol,
                            ),
                            icon: Icons.analytics_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Revenue trend',
                      subtitle: _period == 'Today'
                          ? 'Today by 3-hour window'
                          : formatDate(range.$1),
                    ),
                    const SizedBox(height: 10),
                    SurfaceCard(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                      child: SizedBox(
                        height: 190,
                        child: BarChart(
                          BarChartData(
                            maxY: maxY,
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppPalette.charcoal,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      final bucket = buckets[group.x];
                                      return BarTooltipItem(
                                        '${bucket.label}\n${formatMoney(bucket.value, symbol: shop.symbol, decimals: shop.decimals)}',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                              leftTitles: const AxisTitles(),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 26,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 ||
                                        index >= buckets.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final step = math.max(
                                      1,
                                      (buckets.length / 7).ceil(),
                                    );
                                    if (index % step != 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          buckets[index].label,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxY / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.6),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (var i = 0; i < buckets.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: buckets[i].value,
                                      width: buckets.length > 12 ? 6 : 12,
                                      color: AppPalette.emerald,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Best sellers',
                      subtitle: 'Ranked by revenue',
                    ),
                    const SizedBox(height: 10),
                    if (topProducts.isEmpty)
                      const SurfaceCard(
                        child: EmptyState(
                          icon: Icons.insights_outlined,
                          title: 'No product data',
                          message:
                              'Make a sale in this period to see your best sellers.',
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < math.min(5, topProducts.length);
                                i++) ...[
                              _ProductRank(
                                rank: i + 1,
                                stat: topProducts[i],
                                maxRevenue: topProducts.first.revenue,
                                shop: shop,
                              ),
                              if (i != math.min(5, topProducts.length) - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Payment mix',
                      subtitle: 'How customers paid',
                    ),
                    const SizedBox(height: 10),
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: payments.isEmpty
                          ? const Text('No payments in this period.')
                          : Column(
                              children: [
                                for (var i = 0;
                                    i < payments.length;
                                    i++) ...[
                                  _PaymentShare(
                                    label: payments[i].key,
                                    value: payments[i].value,
                                    total: revenue,
                                    shop: shop,
                                  ),
                                  if (i != payments.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Expenses',
                      subtitle: 'Costs in this period',
                    ),
                    const SizedBox(height: 10),
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: expenses.isEmpty
                          ? const Text('No expenses recorded for this period.')
                          : Column(
                              children: [
                                _SummaryLine(
                                  label: 'Total expenses',
                                  value: formatMoney(
                                    expenseTotal,
                                    symbol: shop.symbol,
                                    decimals: shop.decimals,
                                  ),
                                  color: AppPalette.danger,
                                ),
                                const SizedBox(height: 8),
                                for (final entry
                                    in _expenseByCategory(expenses).entries)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: _SummaryLine(
                                      label: entry.key,
                                      value: formatMoney(
                                        entry.value,
                                        symbol: shop.symbol,
                                        decimals: shop.decimals,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Map<String, double> _expenseByCategory(List<Expense> expenses) {
    final map = <String, double>{};
    for (final expense in expenses) {
      map.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  List<_Bucket> _buildBuckets(
    List<Sale> sales,
    DateTime start,
    DateTime end,
    String period,
  ) {
    if (period == 'Today') {
      final buckets = [
        for (var i = 0; i < 8; i++)
          _Bucket(label: '${(i * 3).toString().padLeft(2, '0')}h'),
      ];
      for (final sale in sales) {
        final index = (sale.createdAt.hour ~/ 3).clamp(0, 7);
        buckets[index].value += sale.total;
      }
      return buckets;
    }
    final days = end.difference(start).inDays + 1;
    final buckets = [
      for (var i = 0; i < days; i++)
        _Bucket(
          label: formatShortDate(DateTime(start.year, start.month, start.day + i)),
        ),
    ];
    for (final sale in sales) {
      final day = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      final index = day.difference(DateTime(start.year, start.month, start.day)).inDays;
      if (index >= 0 && index < buckets.length) {
        buckets[index].value += sale.total;
      }
    }
    return buckets;
  }
}

class _Bucket {
  _Bucket({required this.label});

  final String label;
  double value = 0;
}

class _ProductStat {
  _ProductStat({required this.name});

  final String name;
  int quantity = 0;
  double revenue = 0;
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({
    required this.shop,
    required this.revenue,
    required this.netProfit,
    required this.expenseTotal,
    required this.saleCount,
  });

  final Shop shop;
  final double revenue;
  final double netProfit;
  final double expenseTotal;
  final int saleCount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
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
                'REVENUE',
                style: TextStyle(
                  color: AppPalette.mint.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '$saleCount transactions',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(
                revenue,
                symbol: shop.symbol,
                decimals: shop.decimals,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(
                label: 'Net profit',
                value: formatMoneyCompact(netProfit, symbol: shop.symbol),
                color: netProfit >= 0 ? AppPalette.mint : const Color(0xFFFF8098),
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              _HeroMetric(
                label: 'Expenses',
                value: formatMoneyCompact(expenseTotal, symbol: shop.symbol),
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

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
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppPalette.emerald,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRank extends StatelessWidget {
  const _ProductRank({
    required this.rank,
    required this.stat,
    required this.maxRevenue,
    required this.shop,
  });

  final int rank;
  final _ProductStat stat;
  final double maxRevenue;
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxRevenue <= 0 ? 0.0 : stat.revenue / maxRevenue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppPalette.emerald,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                stat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${stat.quantity} sold',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatMoneyCompact(stat.revenue, symbol: shop.symbol),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

class _PaymentShare extends StatelessWidget {
  const _PaymentShare({
    required this.label,
    required this.value,
    required this.total,
    required this.shop,
  });

  final String label;
  final double value;
  final double total;
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total <= 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(
              '${(share * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatMoneyCompact(value, symbol: shop.symbol),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 5,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            color: AppPalette.mint,
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
