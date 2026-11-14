import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/expense.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import 'expense_form_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final db = context.read<FirestoreService>();
    if (shop == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ExpenseFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Expense'),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Expense>>(
          stream: db.watchExpenses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading expenses…');
            }
            if (snapshot.hasError) {
              return const ErrorView(
                message: 'Unable to load expenses right now.',
              );
            }
            final expenses = snapshot.data ?? const <Expense>[];
            final now = DateTime.now();
            final monthStart = startOfMonth(now);
            final monthExpenses = expenses
                .where((expense) => !expense.date.isBefore(monthStart))
                .toList();
            final monthTotal = monthExpenses.fold<double>(
              0,
              (sum, expense) => sum + expense.amount,
            );
            final todayTotal = expenses
                .where(
                  (expense) =>
                      expense.date.year == now.year &&
                      expense.date.month == now.month &&
                      expense.date.day == now.day,
                )
                .fold<double>(0, (sum, expense) => sum + expense.amount);

            if (expenses.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_outlined,
                title: 'No expenses recorded',
                message:
                    'Track rent, transport, supplies and more to see your true profit.',
                actionLabel: 'Add expense',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExpenseFormScreen(),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              children: [
                SurfaceCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF23301F), Color(0xFF10160E)],
                  ),
                  borderColor: AppPalette.warning.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPEND IN ${formatMonth(now).toUpperCase()}',
                        style: TextStyle(
                          color: AppPalette.warning.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatMoney(
                          monthTotal,
                          symbol: shop.symbol,
                          decimals: shop.decimals,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${monthExpenses.length} entries · ${formatMoney(todayTotal, symbol: shop.symbol, decimals: shop.decimals)} today',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'All expenses',
                  subtitle: '${expenses.length} recorded',
                ),
                const SizedBox(height: 10),
                for (final expense in expenses) ...[
                  _ExpenseRow(
                    expense: expense,
                    shop: shop,
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExpenseFormScreen(expense: expense),
                      ),
                    ),
                    onDelete: () => _delete(context, expense),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Expense expense) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete expense?',
      message: '“${expense.title}” will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<FirestoreService>().deleteExpense(expense.id);
      if (context.mounted) showAppSnack(context, 'Expense deleted.');
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.shop,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              expenseIcon(expense.category),
              size: 19,
              color: AppPalette.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.category} · ${formatDate(expense.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(
              expense.amount,
              symbol: shop.symbol,
              decimals: shop.decimals,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 19,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete expense')),
            ],
          ),
        ],
      ),
    );
  }
}

IconData expenseIcon(String category) {
  return switch (category) {
    'Rent' => Icons.home_work_outlined,
    'Utilities' => Icons.bolt_outlined,
    'Salaries' => Icons.groups_outlined,
    'Transport' => Icons.local_shipping_outlined,
    'Supplies' => Icons.inventory_2_outlined,
    'Marketing' => Icons.campaign_outlined,
    _ => Icons.receipt_outlined,
  };
}
