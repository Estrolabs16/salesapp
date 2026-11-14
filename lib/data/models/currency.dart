class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimals = 2,
  });

  final String code;
  final String symbol;
  final String name;
  final int decimals;

  String get label => '$code · $name ($symbol)';

  static const List<CurrencyOption> all = [
    CurrencyOption(code: 'TZS', symbol: 'TSh', name: 'Tanzanian Shilling', decimals: 0),
    CurrencyOption(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', decimals: 0),
    CurrencyOption(code: 'UGX', symbol: 'USh', name: 'Ugandan Shilling', decimals: 0),
    CurrencyOption(code: 'RWF', symbol: 'FRw', name: 'Rwandan Franc', decimals: 0),
    CurrencyOption(code: 'USD', symbol: r'$', name: 'US Dollar'),
    CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyOption(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    CurrencyOption(code: 'NGN', symbol: '₦', name: 'Nigerian Naira'),
    CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyOption(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
    CurrencyOption(code: 'CAD', symbol: r'C$', name: 'Canadian Dollar'),
    CurrencyOption(code: 'AUD', symbol: r'A$', name: 'Australian Dollar'),
  ];

  static CurrencyOption byCode(String code) {
    return all.firstWhere(
      (currency) => currency.code == code,
      orElse: () => all.first,
    );
  }
}
