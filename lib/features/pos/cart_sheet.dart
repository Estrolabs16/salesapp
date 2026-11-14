import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/customer.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/cart_controller.dart';
import '../../state/shop_controller.dart';

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  late final TextEditingController _discountController;
  late final TextEditingController _cashController;
  late final TextEditingController _noteController;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartController>();
    _discountController = TextEditingController(
      text: cart.discount == 0 ? '' : _plain(cart.discount),
    );
    _cashController = TextEditingController(
      text: cart.cashReceived == 0 ? '' : _plain(cart.cashReceived),
    );
    _noteController = TextEditingController(text: cart.note);
  }

  @override
  void dispose() {
    _discountController.dispose();
    _cashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _plain(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _checkout() async {
    if (_processing) return;
    final cart = context.read<CartController>();
    if (cart.isEmpty) return;
    if (!cart.hasEnoughCash) {
      showAppSnack(
        context,
        'Cash received is less than the total due.',
        isError: true,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _processing = true);
    final now = DateTime.now();
    final db = context.read<FirestoreService>();
    final currency =
        context.read<ShopController>().shop?.currencyCode ?? 'TZS';
    try {
      final sale = Sale(
        id: '',
        number: saleNumberFor(now),
        items: cart.toSaleItems(),
        subtotal: cart.subtotal,
        discount: cart.effectiveDiscount,
        taxRate: cart.taxRate,
        tax: cart.tax,
        total: cart.total,
        paymentMethod: cart.paymentMethod,
        grossProfit: cart.grossProfit,
        createdAt: now,
        customerId: cart.customer?.id ?? '',
        customerName: cart.customer?.name ?? '',
        note: cart.note,
      );
      final saved = await db.createSale(sale);
      await AppAnalytics.logSale(
        value: saved.total,
        currency: currency,
        itemCount: saved.itemCount,
        paymentMethod: saved.paymentMethod,
      );
      cart.clear();
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final cart = context.watch<CartController>();
    if (shop == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return SizedBox(
          height: maxHeight * 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current order',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} · ${shop.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _processing
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: cart.isEmpty
                    ? EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Your cart is empty',
                        message:
                            'Add products from the register to build an order.',
                        actionLabel: 'Browse products',
                        onAction: () => Navigator.of(context).pop(),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        children: [
                          for (final line in cart.lines) ...[
                            _CartLineTile(
                              line: line,
                              shop: shop,
                              onIncrement: () =>
                                  cart.increment(line.product.id),
                              onDecrement: () =>
                                  cart.decrement(line.product.id),
                              onRemove: () => cart.remove(line.product.id),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Customer',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _CustomerPicker(
                            selected: cart.customer,
                            onChanged: cart.setCustomer,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Payment method',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final method in Sale.paymentMethods)
                                ChoiceChip(
                                  label: Text(method),
                                  selected: cart.paymentMethod == method,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    cart.setPaymentMethod(method);
                                    if (method != Sale.paymentMethods.first) {
                                      _cashController.clear();
                                      cart.setCashReceived(0);
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      cart.setDiscount(_parse(value)),
                                  decoration: InputDecoration(
                                    labelText: 'Discount',
                                    prefixText: '${shop.symbol} ',
                                    helperText: 'Applied before tax',
                                  ),
                                ),
                              ),
                              if (cart.requiresCash) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _cashController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        cart.setCashReceived(_parse(value)),
                                    decoration: InputDecoration(
                                      labelText: 'Cash received',
                                      prefixText: '${shop.symbol} ',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (cart.requiresCash &&
                              cart.cashReceived > 0 &&
                              cart.hasEnoughCash)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.change_circle_outlined,
                                    size: 17,
                                    color: AppPalette.emerald,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Change due ${formatMoney(cart.changeDue, symbol: shop.symbol, decimals: shop.decimals)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _noteController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 2,
                            onChanged: cart.setNote,
                            decoration: const InputDecoration(
                              labelText: 'Order note',
                              hintText: 'Optional',
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
              ),
              if (!cart.isEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _TotalRow(
                          label: 'Subtotal',
                          value: formatMoney(
                            cart.subtotal,
                            symbol: shop.symbol,
                            decimals: shop.decimals,
                          ),
                        ),
                        if (cart.discount > 0)
                          _TotalRow(
                            label: 'Discount',
                            value:
                                '− ${formatMoney(cart.effectiveDiscount, symbol: shop.symbol, decimals: shop.decimals)}',
                            color: AppPalette.danger,
                          ),
                        if (cart.tax > 0)
                          _TotalRow(
                            label: 'Tax (${formatPercent(cart.taxRate)})',
                            value: formatMoney(
                              cart.tax,
                              symbol: shop.symbol,
                              decimals: shop.decimals,
                            ),
                          ),
                        const SizedBox(height: 4),
                        _TotalRow(
                          label: 'Total',
                          value: formatMoney(
                            cart.total,
                            symbol: shop.symbol,
                            decimals: shop.decimals,
                          ),
                          emphasized: true,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _processing ? null : _checkout,
                            child: _processing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppPalette.charcoal,
                                    ),
                                  )
                                : Text(
                                    'Charge ${formatMoney(cart.total, symbol: shop.symbol, decimals: shop.decimals)}',
                                  ),
                          ),
                        ),
                        if (!cart.hasEnoughCash) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Enter the cash received to complete this sale.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppPalette.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _parse(String value) => double.tryParse(value.trim()) ?? 0;
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.shop,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartLine line;
  final Shop shop;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          AvatarBubble(
            label: initialsFor(line.product.name),
            imageUrl: line.product.imageUrl,
            size: 44,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${formatMoney(line.product.sellingPrice, symbol: shop.symbol, decimals: shop.decimals)} each',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(
                  line.lineTotal,
                  symbol: shop.symbol,
                  decimals: shop.decimals,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: line.quantity <= 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    onTap: onDecrement,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${line.quantity}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: line.quantity >= line.product.stock
                        ? null
                        : onIncrement,
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 17),
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: onTap == null
              ? scheme.onSurface.withValues(alpha: 0.3)
              : scheme.onSurface,
        ),
      ),
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.selected, required this.onChanged});

  final Customer? selected;
  final ValueChanged<Customer?> onChanged;

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<Customer>>(
      stream: db.watchCustomers(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const <Customer>[];
        final ids = customers.map((customer) => customer.id).toSet();
        final selectedId = selected != null && ids.contains(selected!.id)
            ? selected!.id
            : '';
        return DropdownButtonFormField<String>(
          key: ValueKey('customer-$selectedId-${customers.length}'),
          initialValue: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline_rounded),
            labelText: 'Attach customer',
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Walk-in customer')),
            for (final customer in customers)
              DropdownMenuItem(
                value: customer.id,
                child: Text(
                  customer.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null || value.isEmpty) {
              onChanged(null);
              return;
            }
            onChanged(customers.firstWhere((customer) => customer.id == value));
          },
        );
      },
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodySmall?.copyWith(
            color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(
            value,
            style: emphasized
                ? style?.copyWith(fontSize: 19)
                : style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
