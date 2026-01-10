// MARK: - DateUtilsTests.swift
// Trailers - tvOS App
// Unit tests for DateUtils functionality

import XCTest
@testable import Trailers

/// Tests for DateUtils date formatting and range calculations.
final class DateUtilsTests: XCTestCase {

    // MARK: - Date Formatting Tests

    func testFormatForAPI() {
        // Given
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let date = Calendar.current.date(from: components)!

        // When
        let formatted = DateUtils.formatForAPI(date)

        // Then
        XCTAssertEqual(formatted, "2024-03-15")
    }

    func testFormatForDisplay() {
        // Given
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 15
        let date = Calendar.current.date(from: components)!

        // When
        let formatted = DateUtils.formatForDisplay(date)

        // Then - format varies by locale, just check it contains the year
        XCTAssertTrue(formatted.contains("2025"))
    }

    func testFormatForDisplayNil() {
        let formatted = DateUtils.formatForDisplay(nil)
        XCTAssertEqual(formatted, Constants.UIStrings.yearTBA)
    }

    func testYearString() {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 1
        let date = Calendar.current.date(from: components)!

        let year = DateUtils.yearString(from: date)
        XCTAssertEqual(year, "2024")
    }

    func testYearStringNil() {
        let year = DateUtils.yearString(from: nil)
        XCTAssertEqual(year, Constants.UIStrings.yearTBA)
    }

    // MARK: - Date Parsing Tests

    func testParseDate() {
        let date = DateUtils.parseDate("2024-07-16")

        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 16)
    }

    func testParseDateEmpty() {
        XCTAssertNil(DateUtils.parseDate(""))
        XCTAssertNil(DateUtils.parseDate(nil))
    }

    func testParseInvalidDate() {
        XCTAssertNil(DateUtils.parseDate("not-a-date"))
    }

    func testParseISO8601() {
        let date = DateUtils.parseISO8601("2024-01-15T10:00:00.000Z")

        XCTAssertNotNil(date)
    }

    func testParseISO8601WithoutFractionalSeconds() {
        let date = DateUtils.parseISO8601("2024-01-15T10:00:00Z")

        XCTAssertNotNil(date)
    }

    // MARK: - Runtime Formatting Tests

    func testFormatRuntime() {
        XCTAssertEqual(DateUtils.formatRuntime(148), "2h 28m")
        XCTAssertEqual(DateUtils.formatRuntime(60), "1h")
        XCTAssertEqual(DateUtils.formatRuntime(45), "45m")
        XCTAssertEqual(DateUtils.formatRuntime(125), "2h 5m")
    }

    func testFormatRuntimeNilOrZero() {
        XCTAssertNil(DateUtils.formatRuntime(nil))
        XCTAssertNil(DateUtils.formatRuntime(0))
    }

    func testFormatEpisodeRuntime() {
        XCTAssertEqual(DateUtils.formatEpisodeRuntime(45), "45 min/episode")
        XCTAssertEqual(DateUtils.formatEpisodeRuntime(22), "22 min/episode")
    }

    func testFormatEpisodeRuntimeNilOrZero() {
        XCTAssertNil(DateUtils.formatEpisodeRuntime(nil))
        XCTAssertNil(DateUtils.formatEpisodeRuntime(0))
    }

    // MARK: - Date Range Tests

    func testUpcomingDateRange() {
        let range = DateUtils.upcomingDateRange()

        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)
        XCTAssertTrue(range.hasConstraints)

        // Start should be tomorrow
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)

        XCTAssertEqual(calendar.startOfDay(for: range.start!), startOfTomorrow)
    }

    func testThisMonthDateRange() {
        let range = DateUtils.thisMonthDateRange()

        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)

        let calendar = Calendar.current
        let now = Date()

        // Start should be first of current month
        let startComponents = calendar.dateComponents([.year, .month], from: range.start!)
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        XCTAssertEqual(startComponents.year, nowComponents.year)
        XCTAssertEqual(startComponents.month, nowComponents.month)
        XCTAssertEqual(calendar.component(.day, from: range.start!), 1)
    }

    func testLast30DaysDateRange() {
        let range = DateUtils.last30DaysDateRange()

        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)

        // End should be today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        XCTAssertEqual(calendar.startOfDay(for: range.end!), today)

        // Start should be 30 days ago
        let expected = calendar.date(byAdding: .day, value: -30, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: range.start!), expected)
    }

    func testLast90DaysDateRange() {
        let range = DateUtils.last90DaysDateRange()

        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expected = calendar.date(byAdding: .day, value: -90, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: range.start!), expected)
    }

    func testThisYearDateRange() {
        let range = DateUtils.thisYearDateRange()

        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Start should be Jan 1
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start!)
        XCTAssertEqual(startComponents.year, currentYear)
        XCTAssertEqual(startComponents.month, 1)
        XCTAssertEqual(startComponents.day, 1)

        // End should be Dec 31
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end!)
        XCTAssertEqual(endComponents.year, currentYear)
        XCTAssertEqual(endComponents.month, 12)
        XCTAssertEqual(endComponents.day, 31)
    }

    func testAllTimeDateRange() {
        let range = DateUtils.allTimeDateRange()

        XCTAssertNil(range.start)
        XCTAssertNil(range.end)
        XCTAssertFalse(range.hasConstraints)
    }

    // MARK: - Date Comparison Tests

    func testCompareDatesDescending() {
        let date1 = DateUtils.parseDate("2024-01-01")!
        let date2 = DateUtils.parseDate("2024-06-01")!

        // Descending (newest first): date2 should come first
        XCTAssertTrue(DateUtils.compareDates(date2, date1, ascending: false))
        XCTAssertFalse(DateUtils.compareDates(date1, date2, ascending: false))
    }

    func testCompareDatesAscending() {
        let date1 = DateUtils.parseDate("2024-01-01")!
        let date2 = DateUtils.parseDate("2024-06-01")!

        // Ascending (oldest first): date1 should come first
        XCTAssertTrue(DateUtils.compareDates(date1, date2, ascending: true))
        XCTAssertFalse(DateUtils.compareDates(date2, date1, ascending: true))
    }

    func testCompareDatesWithNilDescending() {
        let date = DateUtils.parseDate("2024-01-01")!

        // Descending: nil should come last
        XCTAssertTrue(DateUtils.compareDates(date, nil, ascending: false))
        XCTAssertFalse(DateUtils.compareDates(nil, date, ascending: false))
    }

    func testCompareDatesWithNilAscending() {
        let date = DateUtils.parseDate("2024-01-01")!

        // Ascending: nil should come first
        XCTAssertTrue(DateUtils.compareDates(nil, date, ascending: true))
        XCTAssertFalse(DateUtils.compareDates(date, nil, ascending: true))
    }

    func testCompareDatesEqualReturnsEqual() {
        let date = DateUtils.parseDate("2024-01-01")!

        XCTAssertFalse(DateUtils.compareDates(date, date, ascending: true))
        XCTAssertFalse(DateUtils.compareDates(date, date, ascending: false))
    }

    func testCompareDatesNilNilReturnsEqual() {
        XCTAssertFalse(DateUtils.compareDates(nil, nil, ascending: true))
        XCTAssertFalse(DateUtils.compareDates(nil, nil, ascending: false))
    }

    // MARK: - Date Range String Tests

    func testDateRangeStrings() {
        let range = DateUtils.last30DaysDateRange()

        XCTAssertNotNil(range.startString)
        XCTAssertNotNil(range.endString)

        // Strings should be in YYYY-MM-DD format
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        let startMatches = regex.numberOfMatches(in: range.startString!, range: NSRange(range.startString!.startIndex..., in: range.startString!))
        XCTAssertEqual(startMatches, 1)
    }
}
