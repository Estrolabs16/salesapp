import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../data/models/expense.dart';
import '../../data/services/firestore_service.dart';
import '../../state/shop_controller.dart';
import 'expenses_screen.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});

  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController = TextEditingController(text: expense?.title ?? '');
    _amountController = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amount.truncateToDouble() == expense.amount
                ? expense.amount.toStringAsFixed(0)
                : expense.amount.toStringAsFixed(2)),
    );
    _noteController = TextEditingController(text: expense?.note ?? '');
    _category = expense?.category ?? Expense.categories.first;
    _date = expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final db = context.read<FirestoreService>();
      final existing = widget.expense;
      final expense = Expense(
        id: existing?.id ?? db.newExpenseId(),
        title: _titleController.text.trim(),
        category: _category,
        amount: double.tryParse(_amountController.text.trim()) ?? 0,
        note: _noteController.text.trim(),
        date: _date,
        createdAt: existing?.createdAt,
      );
      await db.saveExpense(expense);
      if (existing == null) {
        await AppAnalytics.logExpenseCreated(
          category: expense.category,
          value: expense.amount,
        );
      }
      if (!mounted) return;
      showAppSnack(
        context,
        existing == null ? 'Expense recorded.' : 'Expense updated.',
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
    final editing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit expense' : 'New expense')),
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
                : Text(editing ? 'Save changes' : 'Record expense'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'What was it for?',
                  hintText: 'e.g. Generator fuel',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 2) {
                    return 'Enter an expense title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${shop.symbol} ',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(
                          (value ?? '').trim(),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: [
                        for (final category in Expense.categories)
                          DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  expenseIcon(category),
                                  size: 16,
                                  color: AppPalette.warning,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    category,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    formatDate(_date),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Optional details or reference',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
