import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../data/models/product.dart';
import '../../data/models/shop.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/storage_service.dart';
import '../../state/auth_controller.dart';
import '../../state/shop_controller.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  bool get editing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _categoryController;
  late final TextEditingController _costController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;
  late bool _active;
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    final shop = context.read<ShopController>().shop;
    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _costController = TextEditingController(
      text: product == null ? '' : _plain(product.costPrice),
    );
    _priceController = TextEditingController(
      text: product == null ? '' : _plain(product.sellingPrice),
    );
    _stockController = TextEditingController(text: '${product?.stock ?? 0}');
    _thresholdController = TextEditingController(
      text: '${product?.lowStockThreshold ?? shop?.lowStockThreshold ?? 5}',
    );
    _active = product?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  String _plain(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final db = context.read<FirestoreService>();
      final existing = widget.product;
      final id = existing?.id ?? db.newProductId();
      var imageUrl = existing?.imageUrl ?? '';
      if (_imageBytes != null) {
        imageUrl = await StorageService().uploadProductImage(
          userId: context.read<AuthController>().user?.uid ?? '',
          productId: id,
          bytes: _imageBytes!,
        );
      }
      final product = Product(
        id: id,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        category: _categoryController.text.trim(),
        costPrice: double.tryParse(_costController.text.trim()) ?? 0,
        sellingPrice: double.tryParse(_priceController.text.trim()) ?? 0,
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
        lowStockThreshold:
            int.tryParse(_thresholdController.text.trim()) ?? 5,
        imageUrl: imageUrl,
        active: _active,
        createdAt: existing?.createdAt,
      );
      await db.saveProduct(product);
      if (existing == null) {
        await AppAnalytics.logProductCreated(category: product.category);
      }
      if (!mounted) return;
      showAppSnack(
        context,
        existing == null ? 'Product added.' : 'Product updated.',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopController>().shop;
    final theme = Theme.of(context);
    if (shop == null) return const SizedBox.shrink();
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit product' : 'New product'),
        actions: [
          if (widget.editing)
            IconButton(
              tooltip: 'Delete product',
              onPressed: _saving
                  ? null
                  : () => _deleteProduct(product!, shop),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton(
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
                : Text(widget.editing ? 'Save changes' : 'Add product'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            children: [
              _ImagePicker(
                bytes: _imageBytes,
                existingUrl: product?.imageUrl ?? '',
                onPick: _saving ? null : _pickImage,
                onRemove: _saving
                    ? null
                    : () => setState(() => _imageBytes = null),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  hintText: 'e.g. Bottle of water 500ml',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 2) {
                    return 'Enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 520;
                  final sku = TextFormField(
                    controller: _skuController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'SKU / barcode',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.qr_code_rounded),
                    ),
                  );
                  final category = TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Drinks',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        sku,
                        const SizedBox(height: 14),
                        category,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: sku),
                      const SizedBox(width: 12),
                      Expanded(child: category),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Pricing',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Cost price',
                        prefixText: '${shop.symbol} ',
                      ),
                      validator: _amountValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Selling price',
                        prefixText: '${shop.symbol} ',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid price';
                        }
                        final cost =
                            double.tryParse(_costController.text.trim()) ?? 0;
                        if (parsed < cost) {
                          return 'Below cost';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Stock',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: widget.editing
                            ? 'Current stock'
                            : 'Opening stock',
                        suffixText: 'units',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter a number';
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
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (widget.editing) ...[
                const SizedBox(height: 8),
                Text(
                  'Use stock adjustments in Inventory for day-to-day corrections.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SurfaceSwitch(
                value: _active,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _amountValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  Future<void> _deleteProduct(Product product, Shop shop) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete product?',
      message:
          '${product.name} will be removed from inventory. Past sales are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
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
      if (!mounted) return;
      showAppSnack(context, 'Product deleted.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({
    required this.bytes,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String existingUrl;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = bytes != null || existingUrl.isNotEmpty;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else if (existingUrl.isNotEmpty)
              Image.network(
                existingUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            else
              _placeholder(context),
            if (hasImage)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _RoundAction(
                      icon: Icons.edit_outlined,
                      onTap: onPick,
                    ),
                    const SizedBox(width: 6),
                    _RoundAction(
                      icon: Icons.close_rounded,
                      onTap: onRemove,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              color: AppPalette.emerald,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add a product photo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          Text(
            'Optional · used in the register',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class SurfaceSwitch extends StatelessWidget {
  const SurfaceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCardSwitch(value: value, onChanged: onChanged);
  }
}

class SurfaceCardSwitch extends StatelessWidget {
  const SurfaceCardSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: const Text(
          'Available for sale',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Turn off to hide this product from the register.',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
