
import Foundation

struct DateCalculations {
    static func getNextMonthlyPayment(repetitionDate: Date, currentDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        let repetitionDay = calendar.component(.day, from: repetitionDate)

        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        components.day = repetitionDay

        if let thisMonth = calendar.date(from: components), thisMonth > currentDate {
            return thisMonth
        }

        var nextMonth = currentMonth + 1
        var year = currentYear
        if nextMonth > 12 { nextMonth = 1; year += 1 }

        return handleMonthEndEdgeCase(day: repetitionDay, month: nextMonth, year: year, calendar: calendar)
    }

    static func getNextYearlyPayment(repetitionDate: Date, currentDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let repetitionMonth = calendar.component(.month, from: repetitionDate)
        let repetitionDay = calendar.component(.day, from: repetitionDate)

        var components = DateComponents()
        components.year = currentYear
        components.month = repetitionMonth
        components.day = repetitionDay

        if let thisYear = calendar.date(from: components), thisYear > currentDate {
            return thisYear
        }

        return handleMonthEndEdgeCase(day: repetitionDay, month: repetitionMonth, year: currentYear + 1, calendar: calendar)
    }

    static func getNextRevenueDate(repetitionDate: Date, period: String, currentDate: Date = Date()) -> Date? {
        switch period {
        case "monthly": return getNextMonthlyPayment(repetitionDate: repetitionDate, currentDate: currentDate)
        case "yearly": return getNextYearlyPayment(repetitionDate: repetitionDate, currentDate: currentDate)
        case "once": return repetitionDate > currentDate ? repetitionDate : nil
        default: return nil
        }
    }

    private static func handleMonthEndEdgeCase(day: Int, month: Int, year: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstOfMonth = calendar.date(from: components),
              let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) else {
            return Date()
        }
        let lastDay = calendar.component(.day, from: lastOfMonth)
        components.day = min(day, lastDay)
        return calendar.date(from: components) ?? Date()
    }

    static func generateOccurrences(startDate: Date, period: String, endDate: Date) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            occurrences.append(currentDate)
            if period == "monthly" {
                guard let next = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                currentDate = next
            } else if period == "yearly" {
                guard let next = calendar.date(byAdding: .year, value: 1, to: currentDate) else { break }
                currentDate = next
            } else { break }
        }
        return occurrences
    }

    static func formatPaymentDate(_ date: Date, relativeTo currentDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: currentDate), to: calendar.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days > 1 && days <= 7 { return "In \(days) days" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func shouldHideOnceRevenue(repetitionDate: Date, currentDate: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let repMonth = calendar.component(.month, from: repetitionDate)
        let repYear = calendar.component(.year, from: repetitionDate)
        let curMonth = calendar.component(.month, from: currentDate)
        let curYear = calendar.component(.year, from: currentDate)
        if curYear > repYear { return true }
        if curYear == repYear && curMonth > repMonth { return true }
        return false
    }
}
