// Menu bar label: 🫁 + completion count.

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var storage: StorageManager

    var body: some View {
        let _ = storage.logVersion  // observe log writes to refresh the counter
        let stats = storage.todayStats()
        HStack(spacing: 4) {
            Image(systemName: "lungs.fill")
            if stats.total > 0 {
                Text("\(stats.completed)/\(stats.total)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
        }
    }
}
