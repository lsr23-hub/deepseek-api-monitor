import Foundation

/// Shared currency formatting for balance display.
enum CurrencyFormatter {

    /// Returns the symbol for a currency code.
    static func symbol(for currency: String) -> String {
        currency == "CNY" ? "¥" : "$"
    }

    /// Formats a string amount with the given currency symbol and decimal places.
    static func format(
        _ amountString: String,
        currency: String,
        decimals: Int = 2
    ) -> String {
        let symbol = symbol(for: currency)
        guard let value = Double(amountString) else {
            return "\(symbol)--"
        }
        return String(format: "\(symbol)%.\(decimals)f", value)
    }
}
