import Foundation

/// Slider arithmetic for the weekly allocation.
///
/// Kept as a pure function over `[Int]` so the rule — the whole always sums to
/// 100, locked slices never move — is one readable thing rather than something
/// smeared across a view.
enum AllocationMath {
    static let total = 100

    /// Sets `index` to `requested` and redistributes the unlocked remainder
    /// proportionally, so the result still sums to `total`.
    static func rebalance(
        _ values: [Int],
        changing index: Int,
        to requested: Int,
        locked: Set<Int> = []
    ) -> [Int] {
        var out = values
        guard values.indices.contains(index) else { return out }

        let lockedElsewhere = values.indices
            .filter { $0 != index && locked.contains($0) }
            .reduce(0) { $0 + values[$1] }

        // A slice can never claim what locked slices already hold.
        let ceiling = max(0, total - lockedElsewhere)
        out[index] = min(max(0, requested), ceiling)

        let adjustable = values.indices.filter { $0 != index && !locked.contains($0) }
        guard !adjustable.isEmpty else { return out }

        let budget = max(0, total - out[index] - lockedElsewhere)
        let currentSum = adjustable.reduce(0) { $0 + values[$1] }

        if currentSum <= 0 {
            let each = budget / adjustable.count
            for i in adjustable { out[i] = each }
        } else {
            for i in adjustable {
                let share = Double(values[i]) / Double(currentSum) * Double(budget)
                out[i] = max(0, Int(share.rounded()))
            }
        }

        // Rounding drift lands on the largest adjustable slice, where it is
        // least visible.
        let drift = total - out.reduce(0, +)
        if drift != 0, let fix = adjustable.max(by: { out[$0] < out[$1] }) {
            out[fix] = max(0, out[fix] + drift)
        }

        return out
    }

    static func remainder(_ values: [Int]) -> Int {
        total - values.reduce(0, +)
    }

    /// Spreads whatever is left over the unlocked slices, largest first.
    static func distributeRemainder(_ values: [Int], locked: Set<Int> = []) -> [Int] {
        var out = values
        var left = remainder(values)
        guard left != 0 else { return out }

        let adjustable = values.indices
            .filter { !locked.contains($0) }
            .sorted { out[$0] > out[$1] }
        guard !adjustable.isEmpty else { return out }

        if left > 0 {
            out[adjustable[0]] += left
            return out
        }

        for i in adjustable where left < 0 {
            let take = min(out[i], -left)
            out[i] -= take
            left += take
        }
        return out
    }
}
