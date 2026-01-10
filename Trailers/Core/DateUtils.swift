// MARK: - DateUtils.swift
// Trailers - tvOS App
// Date utilities for TMDB API and display formatting

import Foundation

/// Date utility functions for the Trailers app.
///
/// ## Overview
/// This enum provides all date-related functionality including:
/// - Converting dates to TMDB API format (YYYY-MM-DD)
/// - Computing date range boundaries for filtering
/// - Formatting dates for display
/// - Parsing dates from TMDB responses
///
/// ## TMDB Date Format
/// TMDB uses `YYYY-MM-DD` format for all date parameters. This format is computed
/// in the user's local timezone to ensure correct boundary calculations.
///
/// ## Date Range Definitions
/// - **Upcoming**: Tomorrow through 365 days in the future
/// - **This Month**: First day through last day of current month
/// - **Last 30 Days**: 30 days ago through today
/// - **Last 90 Days**: 90 days ago through today
/// - **This Year**: January 1 through December 31 of current year
/// - **All Time**: No date constraints
enum DateUtils {

    // MARK: - Formatters

    /// Formatter for TMDB API date format (YYYY-MM-DD).
    ///
    /// This formatter uses the current calendar and time zone to ensure
    /// correct date boundary calculations.
    static let tmdbDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Formatter for display dates (e.g., "March 15, 2025").
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// Formatter for year-only display (e.g., "2025").
    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    /// ISO 8601 formatter for parsing TMDB timestamps.
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Alternative ISO 8601 formatter without fractional seconds.
    static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Date Range Types

    /// Represents a date range with optional start and end bounds.
    struct DateRange {
        /// Start date (inclusive), nil means no lower bound.
        let start: Date?

        /// End date (inclusive), nil means no upper bound.
        let end: Date?

        /// TMDB-formatted start date string, or nil if no start date.
        var startString: String? {
            guard let start = start else { return nil }
            return DateUtils.tmdbDateFormatter.string(from: start)
        }

        /// TMDB-formatted end date string, or nil if no end date.
        var endString: String? {
            guard let end = end else { return nil }
            return DateUtils.tmdbDateFormatter.string(from: end)
        }

        /// Returns true if this range has any date constraints.
        var hasConstraints: Bool {
            start != nil || end != nil
        }
    }

    // MARK: - Date Range Calculations

    /// Computes the date range for "Upcoming" content.
    ///
    /// Range: Tomorrow (start of day) through 365 days from today (end of day).
    ///
    /// - Returns: DateRange with tomorrow as start and today+365 days as end
    static func upcomingDateRange() -> DateRange {
        let calendar = Calendar.current
        let now = Date()

        // Start: tomorrow at start of day
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let startOfTomorrow = calendar.startOfDay(for: tomorrow) as Date?,
              // End: 365 days from today
              let endDate = calendar.date(byAdding: .day, value: 365, to: now) else {
            return DateRange(start: nil, end: nil)
        }

        return DateRange(start: startOfTomorrow, end: endDate)
    }

    /// Computes the date range for "This Month" content.
    ///
    /// Range: First day of current month through last day of current month.
    ///
    /// - Returns: DateRange spanning the current month
    static func thisMonthDateRange() -> DateRange {
        let calendar = Calendar.current
        let now = Date()

        // Get the start of the current month
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              // Get the start of next month
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
              // End of month is one day before start of next month
              let endOfMonth = calendar.date(byAdding: .day, value: -1, to: startOfNextMonth) else {
            return DateRange(start: nil, end: nil)
        }

        return DateRange(start: startOfMonth, end: endOfMonth)
    }

    /// Computes the date range for "Last 30 Days" content.
    ///
    /// Range: 30 days ago (start of day) through today.
    ///
    /// - Returns: DateRange spanning the last 30 days
    static func last30DaysDateRange() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -30, to: today) else {
            return DateRange(start: nil, end: nil)
        }

        return DateRange(start: startDate, end: today)
    }

    /// Computes the date range for "Last 90 Days" content.
    ///
    /// Range: 90 days ago (start of day) through today.
    ///
    /// - Returns: DateRange spanning the last 90 days
    static func last90DaysDateRange() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -90, to: today) else {
            return DateRange(start: nil, end: nil)
        }

        return DateRange(start: startDate, end: today)
    }

    /// Computes the date range for "This Year" content.
    ///
    /// Range: January 1 through December 31 of the current year.
    ///
    /// - Returns: DateRange spanning the current year
    static func thisYearDateRange() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)

        // Start: January 1 of current year
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              // End: December 31 of current year
              let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return DateRange(start: nil, end: nil)
        }

        return DateRange(start: startOfYear, end: endOfYear)
    }

    /// Returns an empty date range (no constraints) for "All Time".
    ///
    /// - Returns: DateRange with no start or end bounds
    static func allTimeDateRange() -> DateRange {
        DateRange(start: nil, end: nil)
    }

    // MARK: - Formatting

    /// Formats a date for TMDB API queries.
    ///
    /// - Parameter date: The date to format
    /// - Returns: Date string in YYYY-MM-DD format
    static func formatForAPI(_ date: Date) -> String {
        tmdbDateFormatter.string(from: date)
    }

    /// Formats a date for display (e.g., "March 15, 2025").
    ///
    /// - Parameter date: The date to format, or nil
    /// - Returns: Formatted date string, or "TBA" if date is nil
    static func formatForDisplay(_ date: Date?) -> String {
        guard let date = date else {
            return Constants.UIStrings.yearTBA
        }
        return displayDateFormatter.string(from: date)
    }

    /// Extracts the year from a date for display.
    ///
    /// - Parameter date: The date to extract year from, or nil
    /// - Returns: Year string (e.g., "2025"), or "TBA" if date is nil
    static func yearString(from date: Date?) -> String {
        guard let date = date else {
            return Constants.UIStrings.yearTBA
        }
        return yearFormatter.string(from: date)
    }

    // MARK: - Parsing

    /// Parses a TMDB date string (YYYY-MM-DD) into a Date.
    ///
    /// - Parameter dateString: The date string to parse, or nil
    /// - Returns: Parsed Date, or nil if parsing fails or input is nil/empty
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else {
            return nil
        }
        return tmdbDateFormatter.date(from: dateString)
    }

    /// Parses an ISO 8601 timestamp from TMDB (used in video publish dates).
    ///
    /// - Parameter timestamp: The ISO 8601 timestamp string
    /// - Returns: Parsed Date, or nil if parsing fails
    static func parseISO8601(_ timestamp: String?) -> Date? {
        guard let timestamp = timestamp else { return nil }

        // Try with fractional seconds first
        if let date = iso8601Formatter.date(from: timestamp) {
            return date
        }

        // Fall back to without fractional seconds
        return iso8601FormatterNoFractional.date(from: timestamp)
    }

    // MARK: - Runtime Formatting

    /// Formats runtime minutes as "Xh Ym" (e.g., "2h 15m").
    ///
    /// - Parameter minutes: Total runtime in minutes
    /// - Returns: Formatted runtime string, or nil if minutes is nil or 0
    static func formatRuntime(_ minutes: Int?) -> String? {
        guard let minutes = minutes, minutes > 0 else {
            return nil
        }

        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    /// Formats episode runtime as "X min/episode".
    ///
    /// - Parameter minutes: Episode runtime in minutes
    /// - Returns: Formatted episode runtime string, or nil if minutes is nil or 0
    static func formatEpisodeRuntime(_ minutes: Int?) -> String? {
        guard let minutes = minutes, minutes > 0 else {
            return nil
        }
        return "\(minutes) min/episode"
    }

    // MARK: - Comparison Helpers

    /// Compares two optional dates for sorting purposes.
    ///
    /// For descending sorts (newest first), nil dates sort last.
    /// For ascending sorts (oldest first), nil dates sort first.
    ///
    /// - Parameters:
    ///   - date1: First date to compare
    ///   - date2: Second date to compare
    ///   - ascending: If true, older dates come first; if false, newer dates come first
    /// - Returns: True if date1 should come before date2
    static func compareDates(_ date1: Date?, _ date2: Date?, ascending: Bool) -> Bool {
        switch (date1, date2) {
        case (nil, nil):
            return false // Equal, maintain order
        case (nil, _):
            return ascending // nil first for ascending, last for descending
        case (_, nil):
            return !ascending // non-nil first for descending, last for ascending
        case let (d1?, d2?):
            return ascending ? d1 < d2 : d1 > d2
        }
    }
}

// MARK: - Date Extensions

extension Date {

    /// Returns this date formatted for TMDB API.
    var tmdbDateString: String {
        DateUtils.formatForAPI(self)
    }

    /// Returns this date formatted for display.
    var displayString: String {
        DateUtils.formatForDisplay(self)
    }

    /// Returns the year of this date as a string.
    var yearString: String {
        DateUtils.yearString(from: self)
    }
}
