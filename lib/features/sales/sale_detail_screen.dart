import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/export.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import 'receipt.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late Sale _sale = widget.sale;
  bool _working = false;

  Future<void> _share() async {
    final shop = context.read<ShopController>().shop;
    if (shop == null) return;
    try {
      await shareText(
        text: buildReceiptText(shop, _sale),
        subject: 'Receipt ${_sale.number}',
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }

  Future<void> _void() async {
    if (_sale.isVoided || _working) return;
    final confirmed = await confirmAction(
      context,
      title: 'Void this sale?',
      message:
          'Stock will be returned to inventory and the sale will be marked as voided. This cannot be undone.',
      confirmLabel: 'Void sale',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await context.read<FirestoreService>().voidSale(_sale);
      if (!mounted) return;
      setState(() {
        _sale = _sale.copyWith(status: 'voided', voidedAt: DateTime.now());
      });
      showAppSnack(context, 'Sale voided and stock restored.');
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    if (shop == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale receipt'),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share receipt',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          _SaleHero(sale: _sale, shop: shop),
          if (_sale.isVoided) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              borderColor: AppPalette.danger.withValues(alpha: 0.4),
              color: AppPalette.danger.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color: AppPalette.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sale.voidedAt == null
                          ? 'This sale has been voided and stock was restored.'
                          : 'Voided ${formatDateTime(_sale.voidedAt!)}. Stock was restored.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                _MetaRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Customer',
                  value: _sale.customerName.isEmpty
                      ? 'Walk-in customer'
                      : _sale.customerName,
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.payments_outlined,
                  label: 'Payment',
                  value: _sale.paymentMethod,
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Items',
                  value: '${_sale.itemCount} units · ${_sale.items.length} lines',
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.trending_up_rounded,
                  label: 'Gross profit',
                  value: formatMoney(
                    _sale.grossProfit,
                    symbol: shop.symbol,
                    decimals: shop.decimals,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SaleReceiptCard(shop: shop, sale: _sale),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _working ? null : _share,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Share receipt'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sale.isVoided || _working ? null : _void,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.danger,
              side: BorderSide(
                color: AppPalette.danger.withValues(alpha: 0.5),
              ),
            ),
            icon: _working
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.undo_rounded, size: 18),
            label: Text(_sale.isVoided ? 'Sale voided' : 'Void sale'),
          ),
        ],
      ),
    );
  }
}

class _SaleHero extends StatelessWidget {
  const _SaleHero({required this.sale, required this.shop});

  final Sale sale;
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderColor: (sale.isVoided ? AppPalette.danger : AppPalette.emerald)
          .withValues(alpha: 0.35),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: sale.isVoided
            ? const [Color(0xFF3A121B), Color(0xFF12080A)]
            : const [Color(0xFF123A2C), Color(0xFF07120D)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: sale.isVoided ? 'Voided' : 'Completed',
                color: sale.isVoided ? const Color(0xFFFF8098) : AppPalette.mint,
                icon: sale.isVoided
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              const Spacer(),
              Text(
                sale.number,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'TOTAL',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(
                sale.total,
                symbol: shop.symbol,
                decimals: shop.decimals,
              ),
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatDateTime(sale.createdAt),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
