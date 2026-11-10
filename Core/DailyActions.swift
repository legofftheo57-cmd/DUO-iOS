import Foundation

extension Snapshot {
    /// Refuse stale UI commands instead of resurrecting deleted or completed records.
    public func current(_ expected: Record) throws -> Record {
        guard let saved = records.first(where: { $0.id == expected.id }), !saved.deleted,
              saved == expected else { throw DuoError.invalid("Cet élément a changé. Revenez à la liste puis réessayez.") }
        return saved
    }
    public mutating func completeTask(_ expected: Record, at now: Date = Date()) throws {
        var row = try current(expected)
        guard case .task(var task) = row.payload, task.completed == nil else { return }
        // Work on a copy so even direct callers get all-or-nothing semantics.
        var next = self
        if let due = TimeRules.nextDue(task, completion: now) {
            let id = TimeRules.nextTaskID(row.id)
            if let existing = records.first(where: { $0.id == id }), !existing.deleted {
                throw DuoError.invalid("Une prochaine occurrence existe déjà. Aucune tâche n’a été écrasée.")
            }
            let following = HouseTask(title: task.title, assignee: task.assignee, due: due, repeatDays: task.repeatDays)
            try next.put(Record(id: id, householdID: householdID, ownerID: row.ownerID, payload: .task(following)))
        }
        task.completed = now; row.payload = .task(task)
        try next.put(row); self = next
    }
    public mutating func reopenTask(_ expected: Record) throws {
        var row = try current(expected)
        guard case .task(var task) = row.payload, let completedAt = task.completed else {
            throw DuoError.invalid("Cette tâche n’est pas terminée.")
        }
        var next = self
        if task.repeatDays > 0, let successor = records.first(where: { $0.id == TimeRules.nextTaskID(row.id) && !$0.deleted }) {
            guard case .task(let following) = successor.payload, successor.revision == 0,
                  successor.ownerID == row.ownerID, following.completed == nil,
                  following.title == task.title, following.assignee == task.assignee,
                  following.repeatDays == task.repeatDays,
                  following.due == TimeRules.nextDue(task, completion: completedAt) else {
                throw DuoError.invalid("La prochaine occurrence a déjà été modifiée. Elle est conservée ; réouverture annulée.")
            }
            var removed = successor; removed.deleted = true; try next.put(removed)
        }
        task.completed = nil; row.payload = .task(task)
        try next.put(row); self = next
    }
    public mutating func putShopping(_ item: Shopping, editing expected: Record? = nil) throws {
        try Content.shopping(item).validate()
        if let expected {
            var row = try current(expected); row.payload = .shopping(item); try put(row); return
        }
        if !item.checked, let row = records.first(where: {
            guard !$0.deleted, case .shopping(let existing) = $0.payload else { return false }
            return !existing.checked && existing.ingredient.key == item.ingredient.key
        }), case .shopping(var existing) = row.payload {
            existing.ingredient.quantity += try item.ingredient.unit.convert(item.ingredient.quantity, to: existing.ingredient.unit)
            // An explicitly edited/added quantity must survive a later meal recalculation.
            existing.generated = false
            var merged = row; merged.payload = .shopping(existing); try put(merged)
        } else { try put(Record(householdID: householdID, payload: .shopping(item))) }
    }
}
