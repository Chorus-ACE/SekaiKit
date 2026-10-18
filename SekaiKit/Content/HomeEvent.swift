import Foundation

extension Event {
    /// Selects the event to feature on a regional home page.
    ///
    /// An ongoing event takes priority, followed by the nearest upcoming event,
    /// then the most recently started event. Records missing a regional start
    /// date are ignored. Gameplay ends at aggregation time when available.
    ///
    /// - Parameters:
    ///   - events: The available events.
    ///   - locale: The edition whose schedule should be evaluated.
    ///   - date: The reference time. The default is the current time.
    /// - Returns: The selected event, or `nil` if no regional schedule is available.
    public static func featuredEvent(in events: [Event], locale: SekaiLocale, at date: Date = .now) -> Event? {
        let scheduled = events.compactMap { event -> (event: Event, start: Date, end: Date?)? in
            guard let start = event.startDate.localizedData?[locale] else { return nil }
            return (event, start, event.aggregateDate.localizedData?[locale] ?? event.endDate.localizedData?[locale])
        }
        let ongoing = scheduled.filter { $0.start <= date && ($0.end.map { date < $0 } ?? false) }
        if let current = ongoing.max(by: { ($0.start, $0.event.id) < ($1.start, $1.event.id) }) { return current.event }
        if let next = scheduled.filter({ $0.start > date }).min(by: { ($0.start, $0.event.id) < ($1.start, $1.event.id) }) { return next.event }
        return scheduled.max(by: { ($0.start, $0.event.id) < ($1.start, $1.event.id) })?.event
    }
}
