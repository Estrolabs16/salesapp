import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/product.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/storage_service.dart';
import '../../state/auth_controller.dart';
import '../../state/shop_controller.dart';
import 'product_form_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'All';

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
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ProductFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Product'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Products, pricing and stock levels.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search products',
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
              child: StreamBuilder<List<Product>>(
                stream: db.watchProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(message: 'Loading inventory…');
                  }
                  if (snapshot.hasError) {
                    return const ErrorView(
                      message: 'Unable to load inventory right now.',
                    );
                  }
                  final products = snapshot.data ?? const <Product>[];
                  final stockValue = products.fold<double>(
                    0,
                    (sum, product) => sum + product.stockValue,
                  );
                  final lowCount = products
                      .where((product) => product.isLowStock)
                      .length;
                  final query = _query.toLowerCase();
                  final visible = products.where((product) {
                    final matchesFilter = switch (_filter) {
                      'Low' => product.isLowStock,
                      'Out' => product.isOutOfStock,
                      _ => true,
                    };
                    final matchesQuery =
                        query.isEmpty ||
                        product.name.toLowerCase().contains(query) ||
                        product.sku.toLowerCase().contains(query) ||
                        product.category.toLowerCase().contains(query);
                    return matchesFilter && matchesQuery;
                  }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SummaryPill(
                                label: 'Products',
                                value: '${products.length}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryPill(
                                label: 'Stock value',
                                value: formatMoneyCompact(
                                  stockValue,
                                  symbol: shop.symbol,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryPill(
                                label: 'Low stock',
                                value: '$lowCount',
                                accent: lowCount > 0
                                    ? AppPalette.warning
                                    : AppPalette.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            for (final filter in const ['All', 'Low', 'Out']) ...[
                              ChoiceChip(
                                label: Text(
                                  filter == 'Low'
                                      ? 'Low stock'
                                      : filter == 'Out'
                                      ? 'Out of stock'
                                      : 'All',
                                ),
                                selected: _filter == filter,
                                showCheckmark: false,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? EmptyState(
                                icon: products.isEmpty
                                    ? Icons.inventory_2_outlined
                                    : Icons.search_off_rounded,
                                title: products.isEmpty
                                    ? 'Add your first product'
                                    : 'Nothing here',
                                message: products.isEmpty
                                    ? 'Products you add will appear in the register and stock reports.'
                                    : 'Try changing your search or filter.',
                                actionLabel: products.isEmpty
                                    ? 'Add product'
                                    : null,
                                onAction: products.isEmpty
                                    ? () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ProductFormScreen(),
                                        ),
                                      )
                                    : null,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  96,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final product = visible[index];
                                  return _ProductRow(
                                    product: product,
                                    shop: shop,
                                    onEdit: () =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ProductFormScreen(
                                              product: product,
                                            ),
                                          ),
                                        ),
                                    onAdjust: () => _adjustStock(product),
                                    onDelete: () =>
                                        _deleteProduct(product),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustStock(Product product) async {
    final delta = await showDialog<int>(
      context: context,
      builder: (_) => _StockDialog(product: product),
    );
    if (delta == null || delta == 0 || !mounted) return;
    try {
      await context.read<FirestoreService>().adjustStock(product, delta);
      if (mounted) {
        showAppSnack(
          context,
          delta > 0
              ? 'Added $delta units to ${product.name}.'
              : 'Removed ${delta.abs()} units from ${product.name}.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete product?',
      message:
          '${product.name} will be removed from inventory. Past sales are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final db = context.read<FirestoreService>();
    final uid = context.read<AuthController>().user?.uid ?? '';
    try {
      if (product.hasImage) {
        await StorageService().deleteProductImage(
          userId: uid,
          productId: product.id,
        );
      }
      await db.deleteProduct(product.id);
      if (mounted) showAppSnack(context, 'Product deleted.');
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    this.accent = AppPalette.emerald,
  });

  final String label;
  final String value;
  final Color accent;

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

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.shop,
    required this.onEdit,
    required this.onAdjust,
    required this.onDelete,
  });

  final Product product;
  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = product.isOutOfStock
        ? AppPalette.danger
        : product.isLowStock
        ? AppPalette.warning
        : AppPalette.emerald;
    final label = product.isOutOfStock
        ? 'Out'
        : '${product.stock} left';
    return SurfaceCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          AvatarBubble(
            label: initialsFor(product.name),
            imageUrl: product.imageUrl,
            size: 46,
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
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!product.active) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(
                        label: 'Hidden',
                        color: AppPalette.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  product.sku.isEmpty
                      ? (product.category.isEmpty
                            ? 'No SKU'
                            : product.category)
                      : product.sku,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(
                  product.sellingPrice,
                  symbol: shop.symbol,
                  decimals: shop.decimals,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              StatusBadge(label: label, color: badgeColor),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 19,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'adjust':
                  onAdjust();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit product')),
              PopupMenuItem(value: 'adjust', child: Text('Adjust stock')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product});

  final Product product;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _controller = TextEditingController();
  bool _add = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_controller.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero');
      return;
    }
    if (!_add && quantity > widget.product.stock) {
      setState(() => _error = 'You only have ${widget.product.stock} on hand');
      return;
    }
    Navigator.of(context).pop(_add ? quantity : -quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjust stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.product.name} · ${widget.product.stock} on hand',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Add'),
                icon: Icon(Icons.add_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text('Remove'),
                icon: Icon(Icons.remove_rounded),
              ),
            ],
            selected: {_add},
            onSelectionChanged: (values) =>
                setState(() => _add = values.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Quantity',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }
}
