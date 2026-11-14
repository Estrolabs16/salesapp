import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/cart_controller.dart';
import '../../state/shop_controller.dart';
import '../inventory/product_form_screen.dart';
import '../sales/sale_detail_screen.dart';
import 'cart_sheet.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCart() async {
    final sale = await showAppSheet<Sale>(
      context,
      child: const CartSheet(),
    );
    if (sale == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(sale: sale)),
    );
  }

  void _addToCart(Product product) {
    final added = context.read<CartController>().add(product);
    HapticFeedback.selectionClick();
    if (!added) {
      showAppSnack(
        context,
        product.stock <= 0
            ? '${product.name} is out of stock.'
            : 'All available stock of ${product.name} is already in the cart.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final db = context.read<FirestoreService>();
    if (shop == null) return const SizedBox.shrink();

    return SafeArea(
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
                        'Point of sale',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap a product to add it to the cart.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer<CartController>(
                  builder: (context, cart, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _openCart,
                          icon: const Icon(Icons.shopping_bag_outlined),
                          tooltip: 'Cart',
                        ),
                        if (cart.itemCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: const BoxDecoration(
                                color: AppPalette.emerald,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products, SKU or category',
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
                  return const LoadingView(message: 'Loading products…');
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Unable to load products right now.',
                    onRetry: () => setState(() {}),
                  );
                }
                final all = (snapshot.data ?? const <Product>[])
                    .where((product) => product.active)
                    .toList();
                final categories = <String>{
                  for (final product in all)
                    if (product.category.trim().isNotEmpty)
                      product.category.trim(),
                }.toList()..sort();
                final query = _query.toLowerCase();
                final visible = all.where((product) {
                  final matchesCategory =
                      _category == 'All' || product.category == _category;
                  final matchesQuery =
                      query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      product.sku.toLowerCase().contains(query) ||
                      product.category.toLowerCase().contains(query);
                  return matchesCategory && matchesQuery;
                }).toList();

                return Column(
                  children: [
                    if (categories.isNotEmpty)
                      SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: _category == 'All',
                              onTap: () => setState(() => _category = 'All'),
                            ),
                            for (final category in categories) ...[
                              const SizedBox(width: 8),
                              _CategoryChip(
                                label: category,
                                selected: _category == category,
                                onTap: () =>
                                    setState(() => _category = category),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    Expanded(
                      child: all.isEmpty
                          ? EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No products yet',
                              message:
                                  'Add your first product to start selling. Inventory is shared with the Stock tab.',
                              actionLabel: 'Add product',
                              onAction: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ProductFormScreen(),
                                ),
                              ),
                            )
                          : visible.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              message:
                                  'Try a different search term or category.',
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth > 1000
                                    ? 4
                                    : constraints.maxWidth > 680
                                    ? 3
                                    : 2;
                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    20,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 0.78,
                                      ),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    final product = visible[index];
                                    return _ProductTile(
                                      product: product,
                                      shop: shop,
                                      onTap: () => _addToCart(product),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          Consumer<CartController>(
            builder: (context, cart, _) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} in cart',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                          ),
                          Text(
                            formatMoney(
                              cart.total,
                              symbol: shop.symbol,
                              decimals: shop.decimals,
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openCart,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Review order'),
                    ),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.shop,
    required this.onTap,
  });

  final Product product;
  final Shop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = product.stock <= 0;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: SurfaceCard(
        onTap: disabled ? null : onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(21),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.hasImage)
                      Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${product.stock}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(
                      product.sellingPrice,
                      symbol: shop.symbol,
                      decimals: shop.decimals,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: disabled
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                          : AppPalette.emerald,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF0F1A15),
      alignment: Alignment.center,
      child: const BrandMark(size: 38),
    );
  }
}
