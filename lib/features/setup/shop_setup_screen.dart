import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/models/currency.dart';
import '../../data/models/shop.dart';
import '../../state/auth_controller.dart';
import '../../state/shop_controller.dart';
import '../auth/register_screen.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key, this.editing = false});

  final bool editing;

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ownerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxController;
  late final TextEditingController _thresholdController;
  late CurrencyOption _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopController>().shop;
    _nameController = TextEditingController(text: shop?.name ?? '');
    _ownerController = TextEditingController(text: shop?.ownerName ?? '');
    _phoneController = TextEditingController(text: shop?.phone ?? '');
    _addressController = TextEditingController(text: shop?.address ?? '');
    _taxController = TextEditingController(
      text: (shop?.taxRate ?? 0) == 0
          ? ''
          : (shop!.taxRate).toStringAsFixed(
              shop.taxRate.truncateToDouble() == shop.taxRate ? 0 : 2,
            ),
    );
    _thresholdController = TextEditingController(
      text: '${shop?.lowStockThreshold ?? 5}',
    );
    _currency = shop?.currency ?? CurrencyOption.byCode('TZS');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final controller = context.read<ShopController>();
      final existing = controller.shop;
      final shop = Shop(
        id: existing?.id ?? '',
        name: _nameController.text.trim(),
        ownerName: _ownerController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        currencyCode: _currency.code,
        taxRate: double.tryParse(_taxController.text.trim()) ?? 0,
        lowStockThreshold:
            int.tryParse(_thresholdController.text.trim()) ?? 5,
        setupComplete: true,
        createdAt: existing?.createdAt,
      );
      await controller.save(shop);
      if (!mounted) return;
      if (widget.editing && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      showAppSnack(
        context,
        widget.editing ? 'Shop profile updated.' : 'Your shop is ready.',
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final auth = context.read<AuthController>();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGuest = context.read<AuthController>().isGuest;
    return Scaffold(
      appBar: widget.editing
          ? AppBar(title: const Text('Shop profile'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.editing) ...[
                      const Center(
                        child: BrandHeroMark(size: 78),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to EstroShop',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tell us about your business. You can change these details later.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    Text(
                      'Shop details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Shop name',
                        hintText: 'e.g. Estro Mini Market',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 2) {
                          return 'Enter your shop name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _ownerController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Owner name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      minLines: 1,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Shop address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<CurrencyOption>(
                      initialValue: _currency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      items: [
                        for (final currency in CurrencyOption.all)
                          DropdownMenuItem(
                            value: currency,
                            child: Text(
                              currency.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _currency = value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sales preferences',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _taxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tax / VAT rate',
                              suffixText: '%',
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return null;
                              final rate = double.tryParse(text);
                              if (rate == null || rate < 0 || rate > 100) {
                                return 'Enter 0–100';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _thresholdController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Low stock alert',
                              suffixText: 'units',
                            ),
                            validator: (value) {
                              final threshold =
                                  int.tryParse((value ?? '').trim());
                              if (threshold == null || threshold < 0) {
                                return 'Enter a number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tax is applied to the discounted subtotal at checkout. Low stock alerts appear on your dashboard.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppPalette.charcoal,
                              ),
                            )
                          : Text(
                              widget.editing
                                  ? 'Save changes'
                                  : 'Start using EstroShop',
                            ),
                    ),
                    if (!widget.editing) ...[
                      const SizedBox(height: 12),
                      if (isGuest) ...[
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: const Text('Create account to keep your data'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton(
                        onPressed: _saving ? null : _signOut,
                        child: const Text('Use a different account'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
