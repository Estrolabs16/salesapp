import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';

String buildReceiptText(Shop shop, Sale sale) {
  final buffer = StringBuffer();
  String money(num value) =>
      formatMoney(value, symbol: shop.symbol, decimals: shop.decimals);

  buffer.writeln('ESTROSHOP');
  buffer.writeln(shop.name);
  if (shop.address.isNotEmpty) buffer.writeln(shop.address);
  if (shop.phone.isNotEmpty) buffer.writeln(shop.phone);
  buffer.writeln('--------------------------------');
  buffer.writeln('Receipt: ${sale.number}');
  buffer.writeln('Date: ${formatDateTime(sale.createdAt)}');
  buffer.writeln(
    'Customer: ${sale.customerName.isEmpty ? 'Walk-in customer' : sale.customerName}',
  );
  buffer.writeln('Payment: ${sale.paymentMethod}');
  if (sale.isVoided) buffer.writeln('*** VOIDED SALE ***');
  buffer.writeln('--------------------------------');
  for (final item in sale.items) {
    buffer.writeln(item.name);
    buffer.writeln(
      '${item.quantity} x ${money(item.unitPrice)} = ${money(item.lineTotal)}',
    );
  }
  buffer.writeln('--------------------------------');
  buffer.writeln('Subtotal: ${money(sale.subtotal)}');
  if (sale.discount > 0) buffer.writeln('Discount: -${money(sale.discount)}');
  if (sale.tax > 0) {
    buffer.writeln('Tax (${formatPercent(sale.taxRate)}): ${money(sale.tax)}');
  }
  buffer.writeln('TOTAL: ${money(sale.total)}');
  if (sale.note.isNotEmpty) {
    buffer.writeln('--------------------------------');
    buffer.writeln('Note: ${sale.note}');
  }
  buffer.writeln('--------------------------------');
  buffer.writeln('Thank you for your business.');
  buffer.writeln('Powered by EstroShop');
  return buffer.toString();
}

class SaleReceiptCard extends StatelessWidget {
  const SaleReceiptCard({super.key, required this.shop, required this.sale});

  final Shop shop;
  final Sale sale;

  String _money(num value) =>
      formatMoney(value, symbol: shop.symbol, decimals: shop.decimals);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              shop.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (shop.address.isNotEmpty) ...[
            const SizedBox(height: 3),
            Center(
              child: Text(
                shop.address,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(sale.number, style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                formatDateTime(sale.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 8),
          for (final item in sale.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${item.quantity} x ${_money(item.unitPrice)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _money(item.lineTotal),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: 8),
          _ReceiptRow(label: 'Subtotal', value: _money(sale.subtotal)),
          if (sale.discount > 0)
            _ReceiptRow(
              label: 'Discount',
              value: '-${_money(sale.discount)}',
              color: AppPalette.danger,
            ),
          if (sale.tax > 0)
            _ReceiptRow(
              label: 'Tax (${formatPercent(sale.taxRate)})',
              value: _money(sale.tax),
            ),
          const SizedBox(height: 4),
          _ReceiptRow(
            label: 'Total',
            value: _money(sale.total),
            emphasized: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Paid by ${sale.paymentMethod}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (sale.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${sale.note}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text(
              sale.isVoided ? 'VOIDED' : 'Thank you for your business',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: sale.isVoided ? AppPalette.danger : AppPalette.emerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
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
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodySmall?.copyWith(
            color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
