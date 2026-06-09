//
//  Dive_Tip_OutTests.swift
//  Dive Tip-OutTests
//
//  Created by david pamatz on 6/9/26.
//

import Foundation
import Testing
@testable import Dive_Tip_Out

struct Dive_Tip_OutTests {

    @Test func workedExampleMatchesRequiredPayouts() async throws {
        let bartenders = [
            TipCalculator.BartenderInput(id: UUID(), name: "Bartender 1", foodSales: decimal("60"), hours: decimal("7.5")),
            TipCalculator.BartenderInput(id: UUID(), name: "Bartender 2", foodSales: decimal("120"), hours: decimal("8.5")),
            TipCalculator.BartenderInput(id: UUID(), name: "Bartender 3", foodSales: decimal("600"), hours: decimal("9.5"))
        ]
        let barbacks = [
            TipCalculator.BarbackInput(id: UUID(), name: "Barback 1", hours: decimal("10.5")),
            TipCalculator.BarbackInput(id: UUID(), name: "Barback 2", hours: decimal("9.5"))
        ]

        let result = TipCalculator.calculate(
            totalTips: decimal("1000"),
            bartenders: bartenders,
            barbacks: barbacks,
            foodRunnerCount: 1
        )

        #expect(result.combinedFoodSales == decimal("780"))
        #expect(result.foodRunnerTipOut == decimal("31"))
        #expect(result.truePooledTips == decimal("969"))
        #expect(result.barbackPool == decimal("145"))
        #expect(result.bartenderPool == decimal("824"))
        #expect(AppFormat.rate(result.bartenderHourlyRate) == "$32.3137/hr")
        #expect(AppFormat.rate(result.barbackHourlyRate) == "$7.2500/hr")
        #expect(result.bartenderPayouts.map(\.takeHome) == [decimal("242"), decimal("274"), decimal("306")])
        #expect(result.barbackPayouts.map(\.takeHome) == [decimal("76"), decimal("68")])
        #expect(result.bartenderRoundingOverage == decimal("2"))
        #expect(result.barbackRoundingOverage == decimal("1"))
        #expect(result.overage == decimal("3"))
    }

}

private func decimal(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}
