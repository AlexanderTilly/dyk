/// Formats integer euro-cents for display: 499 → "€4.99".
String euros(int cents) => '€${(cents / 100).toStringAsFixed(2)}';
