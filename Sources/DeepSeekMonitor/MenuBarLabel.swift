import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var viewModel: BalanceViewModel

    var body: some View {
        HStack(spacing: 3) {
            Text("🐋")
                .font(.system(size: 11))

            if let balance = viewModel.primaryBalance {
                Text(formattedBalance(balance))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            } else if viewModel.isLoading {
                Text("···")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func formattedBalance(_ info: BalanceInfo) -> String {
        let symbol = CurrencyFormatter.symbol(for: info.currency)
        guard let total = Double(info.totalBalance) else {
            return "\(symbol)--"
        }
        // Compact format: show 2 decimals if < 100, else integer
        if total < 100 {
            return String(format: "\(symbol)%.2f", total)
        } else {
            return String(format: "\(symbol)%.0f", total)
        }
    }
}
