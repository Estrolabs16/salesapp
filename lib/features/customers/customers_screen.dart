import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/customer.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final db = context.read<FirestoreService>();
    if (shop == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerFormScreen(),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'New customer',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CustomerFormScreen(),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Customer'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or email',
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
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: db.watchCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(message: 'Loading customers…');
                  }
                  if (snapshot.hasError) {
                    return const ErrorView(
                      message: 'Unable to load customers right now.',
                    );
                  }
                  final customers = snapshot.data ?? const <Customer>[];
                  final query = _query.toLowerCase();
                  final visible = customers.where((customer) {
                    if (query.isEmpty) return true;
                    return customer.name.toLowerCase().contains(query) ||
                        customer.phone.toLowerCase().contains(query) ||
                        customer.email.toLowerCase().contains(query);
                  }).toList();
                  if (visible.isEmpty) {
                    return EmptyState(
                      icon: customers.isEmpty
                          ? Icons.people_outline_rounded
                          : Icons.search_off_rounded,
                      title: customers.isEmpty
                          ? 'No customers yet'
                          : 'No matches',
                      message: customers.isEmpty
                          ? 'Add regular customers to attach them to sales and track spend.'
                          : 'Try another name, phone number or email.',
                      actionLabel: customers.isEmpty ? 'Add customer' : null,
                      onAction: customers.isEmpty
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CustomerFormScreen(),
                              ),
                            )
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = visible[index];
                      return _CustomerRow(
                        customer: customer,
                        shop: shop,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CustomerFormScreen(customer: customer),
                          ),
                        ),
                        onDelete: () => _delete(customer),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete customer?',
      message:
          '${customer.name} will be removed from your customer list. Past sales are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<FirestoreService>().deleteCustomer(customer.id);
      if (mounted) showAppSnack(context, 'Customer deleted.');
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.shop,
    required this.onTap,
    required this.onDelete,
  });

  final Customer customer;
  final Shop shop;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (customer.phone.isNotEmpty) customer.phone,
      if (customer.email.isNotEmpty) customer.email,
    ].join(' · ');
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          AvatarBubble(label: initialsFor(customer.name), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.isEmpty ? 'No contact details' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      size: 12,
                      color: AppPalette.emerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${formatMoneyCompact(customer.totalSpent, symbol: shop.symbol)} spent',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppPalette.emerald,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${customer.visits} visits',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
              PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
        ],
      ),
    );
  }
}
