import Foundation

public struct PurchasePrice: Codable, Sendable {
    public var key: String; public var packQuantity: Double; public var unit: FoodUnit; public var euros: Double; public var observed: Date; public var source: String
    public init(key: String, packQuantity: Double, unit: FoodUnit, euros: Double, observed: Date, source: String) { self.key = key; self.packQuantity = packQuantity; self.unit = unit; self.euros = euros; self.observed = observed; self.source = source }
}
public enum MealEngine {
    public static func requirements(_ meals: [Meal], catalog: [Recipe]) throws -> [Ingredient] {
        var totals: [String: Ingredient] = [:]
        for meal in meals where !meal.cooked {
            guard (1...12).contains(meal.portions), let recipe = catalog.first(where: { $0.id == meal.recipeID }), recipe.portions > 0 else { throw DuoError.invalid("Recette ou portions invalides.") }
            for i in recipe.ingredients {
                var base = Ingredient(i.name, i.quantity * i.unit.factor * Double(meal.portions) / Double(recipe.portions), i.unit.base)
                if base.unit == .piece { base.quantity = ceil(base.quantity) }
                if let old = totals[base.key] { base.quantity += old.quantity }
                totals[base.key] = base
            }
        }
        return totals.values.sorted { $0.key < $1.key }
    }
    public static func missing(_ needs: [Ingredient], stock: [Food], now: Date = Date(), calendar: Calendar = .current) -> [Ingredient] {
        var available: [String: Double] = [:]
        for f in stock where f.quantity > 0 && (f.expiry == nil || calendar.startOfDay(for: f.expiry!) >= calendar.startOfDay(for: now)) {
            let key = Ingredient(f.name, f.quantity, f.unit).key
            available[key, default: 0] += f.quantity * f.unit.factor
        }
        return needs.compactMap { i in
            let needed = i.quantity * i.unit.factor
            let consumed = min(needed, available[i.key, default: 0])
            available[i.key, default: 0] -= consumed
            let deficit = needed - consumed
            return deficit > 0.000001 ? Ingredient(i.name, deficit, i.unit.base) : nil
        }
    }
    /// Allocates each lot once, in meal date order; excludes lots expired on that meal date.
    public static func missingForMeals(_ meals: [Meal], catalog: [Recipe], stock: [Food]) throws -> [Ingredient] {
        var remaining = stock
        var totals: [String: Ingredient] = [:]
        for meal in meals.filter({ !$0.cooked }).sorted(by: { $0.date < $1.date }) {
            let needs = try requirements([meal], catalog: catalog)
            for need in needs {
                var deficit = need.quantity * need.unit.factor
                let indices = remaining.indices.sorted { (remaining[$0].expiry ?? .distantFuture) < (remaining[$1].expiry ?? .distantFuture) }
                for i in indices where deficit > 0 {
                    let food = remaining[i]
                    guard Ingredient(food.name, 0, food.unit).key == need.key,
                          food.expiry == nil || Calendar.current.startOfDay(for: food.expiry!) >= Calendar.current.startOfDay(for: meal.date) else { continue }
                    let used = min(deficit, max(0, food.quantity) * food.unit.factor)
                    deficit -= used; remaining[i].quantity -= used / food.unit.factor
                }
                if deficit > 0.000001 {
                    var item = totals[need.key] ?? Ingredient(need.name, 0, need.unit.base)
                    item.quantity += deficit; totals[need.key] = item
                }
            }
        }
        return totals.values.sorted { $0.key < $1.key }
    }
    public static func cost(_ needs: [Ingredient], prices: [PurchasePrice], now: Date = Date()) -> Double? {
        var total = 0.0
        for i in needs {
            guard let p = prices.filter({ $0.key == i.key && $0.unit.dimension == i.unit.dimension && !$0.source.isEmpty && now.timeIntervalSince($0.observed) >= 0 && now.timeIntervalSince($0.observed) <= 7 * 86400 && $0.packQuantity > 0 && $0.packQuantity.isFinite && $0.euros.isFinite && $0.euros >= 0 }).sorted(by: { $0.observed > $1.observed }).first else { return nil }
            total += ceil(i.quantity * i.unit.factor / (p.packQuantity * p.unit.factor)) * p.euros
        }
        return (total * 100).rounded() / 100
    }
    public static func suggestions(catalog: [Recipe], stock: [Food], exclusions: Set<String>, recent: [String], now: Date = Date()) -> [Recipe] {
        let excluded = Set(exclusions.map(normalized))
        let eligible = catalog.filter { recipe in
            !recipe.ingredients.contains { excluded.contains(normalized($0.name)) } && !recipe.allergens.contains { excluded.contains(normalized($0)) }
        }
        let today = Calendar.current.startOfDay(for: now)
                let soon = Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today
                let urgentKeys = Set(stock.filter { food in
                    guard food.quantity > 0, let expiry = food.expiry else { return false }
                    return expiry >= today && expiry < soon
                }.map { Ingredient($0.name, 0, $0.unit).key })
        func score(_ r: Recipe) -> Int {
                let urgentCount = Set(r.ingredients.map(\.key)).intersection(urgentKeys).count
                return missing(r.ingredients, stock: stock, now: now).count * 10 + (recent.contains(r.id) ? 15 : 0) - urgentCount * 6
            }
        let scores = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, score($0)) })
        return eligible.sorted { a, b in
            let first = scores[a.id, default: 0], second = scores[b.id, default: 0]
            return first == second ? a.id < b.id : first < second
        }
    }
    // Greedy, deterministic heuristic. Never claims a global minimum or a verified budget without prices.
    public static func plan(count: Int, portions: Int, start: Date, catalog: [Recipe], stock: [Food], exclusions: Set<String>, recent: [String], budget: Double?, prices: [PurchasePrice], calendar: Calendar = .current) throws -> [Meal] {
        guard (1...14).contains(count), (1...12).contains(portions) else { throw DuoError.invalid("Choisissez 1 à 14 repas, pour 1 à 12 personnes.") }
        var selected: [Meal] = []; var families: [String: Int] = [:]
        let choices = suggestions(catalog: catalog, stock: stock, exclusions: exclusions, recent: recent, now: start)
        for day in 0..<count {
            let eligible = choices.filter { r in !selected.contains { $0.recipeID == r.id } }
            var ranked: [(Recipe, Double)] = []
            for r in eligible {
                var candidate = selected
                candidate.append(Meal(recipeID: r.id, date: calendar.date(byAdding: .day, value: day, to: start) ?? start, portions: portions))
                let needs = try missingForMeals(candidate, catalog: catalog, stock: stock)
                let price = cost(needs, prices: prices, now: start)
                var score = Double(needs.count * 10)
                score += Double(families[r.family, default: 0] * 12)
                if recent.contains(r.id) { score += 15 }
                if let budget, let price, price > budget { score += 10000 }
                score += price ?? 0
                ranked.append((r, score))
            }
            ranked.sort { a, b in a.1 == b.1 ? a.0.id < b.0.id : a.1 < b.1 }
            guard let choice = ranked.first?.0, let date = calendar.date(byAdding: .day, value: day, to: start) else { break }
            selected.append(Meal(recipeID: choice.id, date: date, portions: portions)); families[choice.family, default: 0] += 1
        }
        return selected
    }
    public static func consume(_ needs: [Ingredient], stock: [Record], now: Date = Date()) throws -> [Record] {
        let foods = stock.compactMap { row -> Food? in if !row.deleted, case .food(let f) = row.payload { return f }; return nil }
        guard missing(needs, stock: foods, now: now).isEmpty else { throw DuoError.invalid("Stock insuffisant ou périmé. Corrigez le frigo avant de confirmer.") }
        var output = stock
        for need in needs {
            var remaining = need.quantity * need.unit.factor
            let indices = output.indices.filter { i in
                if !output[i].deleted, case .food(let f) = output[i].payload { return Ingredient(f.name, 0, f.unit).key == need.key && (f.expiry == nil || Calendar.current.startOfDay(for: f.expiry!) >= Calendar.current.startOfDay(for: now)) }; return false
            }.sorted { a, b in
                if case .food(let fa) = output[a].payload, case .food(let fb) = output[b].payload { return (fa.expiry ?? .distantFuture) < (fb.expiry ?? .distantFuture) }; return false
            }
            for i in indices where remaining > 0 {
                if case .food(var f) = output[i].payload { let take = min(remaining, f.quantity * f.unit.factor); f.quantity = max(0, f.quantity - take / f.unit.factor); remaining -= take; output[i].payload = .food(f) }
            }
        }
        return output
    }
}
public enum TimeRules {
    /// Stable successor identity: simultaneous offline completions address one next task.
    public static func nextTaskID(_ id: UUID) -> UUID {
        let raw = id.uuidString
        let suffix = UInt64(raw.suffix(12), radix: 16) ?? 0
        return UUID(uuidString: String(raw.dropLast(12)) + String(format: "%012llX", (suffix + 1) & 0xFFFFFFFFFFFF))!
    }

    public static func isDark(minute: Int, start: Int, end: Int) -> Bool {
        guard (0..<1440).contains(minute), (0..<1440).contains(start), (0..<1440).contains(end), start != end else { return false }
        return start < end ? minute >= start && minute < end : minute >= start || minute < end
    }
    public static func nextDue(_ task: HouseTask, completion: Date, calendar: Calendar = .current) -> Date? {
        guard task.repeatDays > 0 else { return nil }
        var next = task.due ?? completion
        repeat { guard let d = calendar.date(byAdding: .day, value: task.repeatDays, to: next) else { return nil }; next = d } while next <= completion
        return next
    }
}


/// Local calendar dates keep the daily rotation stable through DST changes.
public enum CoupleSchedule {
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    public static func indices(on date: Date, count: Int, calendar: Calendar = .current) -> [Int] {
        guard count > 0 else { return [] }
        // Convert the local civil date to midnight UTC. Calendar ordinality in
        // an era can count partial 24-hour periods across historical/DST offsets.
        var civil = calendar
        civil.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard let midnight = civil.date(from: components) else { return [] }
        let day = Int(floor(midnight.timeIntervalSince1970 / 86400))
        let base = ((day * 3) % count + count) % count
        return (0..<min(3, count)).map { (base + $0) % count }
    }
}
