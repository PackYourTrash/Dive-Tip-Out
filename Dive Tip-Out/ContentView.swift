//
//  ContentView.swift
//  Dive Tip-Out
//
//  Created by david pamatz on 6/9/26.
//

import Combine
import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: TipOutViewModel
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()

                VStack(spacing: 28) {
                    Spacer(minLength: 36)

                    VStack(spacing: 18) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .blue.opacity(0.28), radius: 10, y: 6)

                        VStack(spacing: 8) {
                            Text("Dive Tip-Out")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)

                            Text("Tonight's tip payout")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.82))
                        }

                        NavigationLink {
                            EntryView()
                        } label: {
                            Label("Begin Tip Payout", systemImage: "arrow.right.circle.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(PrimaryGlassButtonStyle())
                        .padding(.top, 10)

                        Button("Reset") {
                            showingResetConfirmation = true
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.76))
                        .padding(.top, 4)
                    }
                    .glassCard()
                    .padding(.horizontal, 24)

                    Spacer(minLength: 56)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Reset tonight's entries?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetAllEntries()
            }
        } message: {
            Text("This clears the total tips, bartenders, barbacks, and food runners.")
        }
    }
}

struct EntryView: View {
    @EnvironmentObject private var viewModel: TipOutViewModel
    @State private var showingResults = false

    var body: some View {
        ZStack {
            OceanBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TotalTipsSection()
                    BartendersSection()
                    BarbacksSection()
                    FoodRunnersSection()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Tip Payout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            CalculateBar(showingResults: $showingResults)
        }
        .navigationDestination(isPresented: $showingResults) {
            ResultsView()
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject private var viewModel: TipOutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            OceanBackground()

            if let result = viewModel.calculationResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ResultsGroup(title: "Night Summary") {
                            ResultRow("Total tips", AppFormat.money(result.totalTips))
                            ResultRow("Combined food sales", AppFormat.money(result.combinedFoodSales))

                            if result.hasFoodRunnerTipOut {
                                ResultRow("Food runner tip-out", AppFormat.money(result.foodRunnerTipOut))
                            }

                            ResultRow("True pooled tips", AppFormat.money(result.truePooledTips), isEmphasized: true)
                        }

                        ResultsGroup(title: "Bartenders") {
                            ResultRow("Pool", AppFormat.money(result.bartenderPool))
                            ResultRow("Hourly rate", AppFormat.rate(result.bartenderHourlyRate), isEmphasized: true)

                            ForEach(result.bartenderPayouts) { payout in
                                PayoutRow(payout: payout)
                            }
                        }

                        if !result.barbackPayouts.isEmpty {
                            ResultsGroup(title: "Barbacks") {
                                ResultRow("Pool", AppFormat.money(result.barbackPool))
                                ResultRow("Hourly rate", AppFormat.rate(result.barbackHourlyRate), isEmphasized: true)

                                ForEach(result.barbackPayouts) { payout in
                                    PayoutRow(payout: payout)
                                }
                            }
                        }

                        Text("Overage: \(AppFormat.money(result.overage)) (\(AppFormat.money(result.bartenderRoundingOverage)) from bartender rounding + \(AppFormat.money(result.barbackRoundingOverage)) from barback rounding) - hand out as you choose.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .glassCard()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            } else {
                VStack(spacing: 14) {
                    Text("Entries need a quick edit.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(viewModel.calculationValidationMessage ?? "Add the required details before calculating.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)

                    Button("Back to Edit") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryGlassButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    dismiss()
                }
            }
        }
    }
}

struct TotalTipsSection: View {
    @EnvironmentObject private var viewModel: TipOutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Total Tips")

            VStack(alignment: .leading, spacing: 10) {
                FormTextField(
                    title: "Total tips",
                    placeholder: "1000 or 1043.50",
                    text: $viewModel.totalTipsText,
                    keyboardType: .decimalPad
                )

                if !viewModel.totalTipsText.trimmed.isEmpty && viewModel.parsedTotalTips == nil {
                    ValidationText("Enter a zero-or-greater dollar amount.")
                }
            }
            .glassCard()
        }
    }
}

struct BartendersSection: View {
    @EnvironmentObject private var viewModel: TipOutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Bartenders")

            ForEach(viewModel.bartenders.indices, id: \.self) { index in
                StaffEntryCard(
                    member: $viewModel.bartenders[index],
                    role: .bartender,
                    index: index,
                    onDelete: {
                        viewModel.removeBartender(at: index)
                    }
                )
            }

            AddButton(title: "Add Bartender", systemImage: "person.badge.plus") {
                viewModel.addBartender()
            }
        }
    }
}

struct BarbacksSection: View {
    @EnvironmentObject private var viewModel: TipOutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Barbacks")

            ForEach(viewModel.barbacks.indices, id: \.self) { index in
                StaffEntryCard(
                    member: $viewModel.barbacks[index],
                    role: .barback,
                    index: index,
                    onDelete: {
                        viewModel.removeBarback(at: index)
                    }
                )
            }

            AddButton(title: "Add Barback", systemImage: "person.badge.plus") {
                viewModel.addBarback()
            }
        }
    }
}

struct FoodRunnersSection: View {
    @EnvironmentObject private var viewModel: TipOutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Food Runners")

            ForEach(viewModel.foodRunners.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Food Runner \(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            viewModel.removeFoodRunner(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    FormTextField(
                        title: "Name",
                        placeholder: "Enter Food Runner \(index + 1)'s name",
                        text: $viewModel.foodRunners[index].name
                    )
                }
                .glassCard()
            }

            AddButton(title: "Add Food Runner", systemImage: "figure.run") {
                viewModel.addFoodRunner()
            }
        }
    }
}

struct StaffEntryCard: View {
    @Binding var member: CrewMember
    let role: StaffRole
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(role.title) \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            FormTextField(
                title: "Name",
                placeholder: "Enter \(role.title) \(index + 1)'s name",
                text: $member.name
            )

            if role == .bartender {
                FormTextField(
                    title: "Food sales",
                    placeholder: "0 or 120.50",
                    text: $member.foodSalesText,
                    keyboardType: .decimalPad
                )

                if member.foodSalesValue == nil && !member.foodSalesText.trimmed.isEmpty {
                    ValidationText("Food sales need to be zero or more.")
                }
            }

            Picker("Hours input", selection: $member.inputMode) {
                Text("Direct").tag(ShiftInputMode.direct)
                Text("Time Span").tag(ShiftInputMode.timeSpan)
            }
            .pickerStyle(.segmented)

            if member.inputMode == .direct {
                FormTextField(
                    title: "Hours worked",
                    placeholder: "7.5",
                    text: $member.hoursText,
                    keyboardType: .decimalPad
                )
            } else {
                TimeSpanPicker(member: $member)
            }

            if let validation = member.hoursValidationMessage {
                ValidationText(validation)
            }
        }
        .glassCard()
    }
}

struct TimeSpanPicker: View {
    @Binding var member: CrewMember

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Start", selection: $member.startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "en_US"))

            DatePicker("End", selection: $member.endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "en_US"))

            if let hours = member.hoursValue {
                Label("\(AppFormat.hours(hours)) hours", systemImage: "clock")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct CalculateBar: View {
    @EnvironmentObject private var viewModel: TipOutViewModel
    @Binding var showingResults: Bool

    var body: some View {
        VStack(spacing: 8) {
            Button {
                showingResults = true
            } label: {
                Label("Calculate", systemImage: "sum")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryGlassButtonStyle())
            .disabled(!viewModel.canCalculate)
            .opacity(viewModel.canCalculate ? 1 : 0.55)

            if let validation = viewModel.calculationValidationMessage {
                Text(validation)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

struct ResultsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                content
            }
        }
        .glassCard()
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    let isEmphasized: Bool

    init(_ title: String, _ value: String, isEmphasized: Bool = false) {
        self.title = title
        self.value = value
        self.isEmphasized = isEmphasized
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(isEmphasized ? .headline : .subheadline)
                .foregroundStyle(.white.opacity(0.78))

            Spacer(minLength: 12)

            Text(value)
                .font(isEmphasized ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }
}

struct PayoutRow: View {
    let payout: TipCalculator.PersonPayout

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(payout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(AppFormat.hours(payout.hours)) hours")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 12)

            Text(AppFormat.money(payout.takeHome))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
    }
}

struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .shadow(color: .blue.opacity(0.25), radius: 8, y: 4)
    }
}

struct AddButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(SecondaryGlassButtonStyle())
    }
}

struct FormTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.body.weight(.medium))
                .foregroundStyle(Color(red: 0.04, green: 0.18, blue: 0.26))
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ValidationText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.72))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct OceanBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.53, green: 0.82, blue: 0.94),
                Color(red: 0.16, green: 0.60, blue: 0.78),
                Color(red: 0.04, green: 0.30, blue: 0.48),
                Color(red: 0.02, green: 0.20, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.02, green: 0.22, blue: 0.34))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.74 : 0.92))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SecondaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

extension View {
    func glassCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
            )
    }
}

enum StaffRole {
    case bartender
    case barback

    var title: String {
        switch self {
        case .bartender:
            return "Bartender"
        case .barback:
            return "Barback"
        }
    }
}

enum ShiftInputMode: String, Codable, CaseIterable {
    case direct
    case timeSpan
}

struct CrewMember: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var foodSalesText = ""
    var inputMode: ShiftInputMode = .direct
    var hoursText = ""
    var startTime = CrewMember.defaultStartTime()
    var endTime = CrewMember.defaultEndTime()

    var hoursValue: Decimal? {
        switch inputMode {
        case .direct:
            return AppFormat.parseDecimal(hoursText)
        case .timeSpan:
            return ShiftHours.hoursBetween(start: startTime, end: endTime)
        }
    }

    var foodSalesValue: Decimal? {
        if foodSalesText.trimmed.isEmpty {
            return Decimal(0)
        }

        return AppFormat.parseDecimal(foodSalesText)
    }

    var hoursValidationMessage: String? {
        switch inputMode {
        case .direct:
            if hoursText.trimmed.isEmpty {
                return "Enter hours greater than 0."
            }

            guard let hours = hoursValue, hours > Decimal(0) else {
                return "Enter hours greater than 0."
            }

            return nil
        case .timeSpan:
            guard let hours = hoursValue, hours > Decimal(0) else {
                return "End time needs to be after start time."
            }

            return nil
        }
    }

    func displayName(defaultName: String) -> String {
        let trimmedName = name.trimmed
        return trimmedName.isEmpty ? defaultName : trimmedName
    }

    private static func defaultStartTime() -> Date {
        Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static func defaultEndTime() -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

struct FoodRunner: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""

    func displayName(defaultName: String) -> String {
        let trimmedName = name.trimmed
        return trimmedName.isEmpty ? defaultName : trimmedName
    }
}

struct StoredNight: Codable {
    var dateKey: String
    var totalTipsText: String
    var bartenders: [CrewMember]
    var barbacks: [CrewMember]
    var foodRunners: [FoodRunner]
}

final class TipOutViewModel: ObservableObject {
    @Published var totalTipsText = "" {
        didSet { saveIfReady() }
    }

    @Published var bartenders: [CrewMember] = [] {
        didSet { saveIfReady() }
    }

    @Published var barbacks: [CrewMember] = [] {
        didSet { saveIfReady() }
    }

    @Published var foodRunners: [FoodRunner] = [] {
        didSet { saveIfReady() }
    }

    private let defaults: UserDefaults
    private let storageKey = "DiveTipOut.currentNight"
    private var isRestoring = false
    private var storedDateKey = TipOutViewModel.dateKey(for: Date()) {
        didSet { saveIfReady() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadStoredNight()
        resetIfNeededForNewDay()
    }

    var parsedTotalTips: Decimal? {
        AppFormat.parseDecimal(totalTipsText)
    }

    var canCalculate: Bool {
        calculationValidationMessage == nil
    }

    var calculationValidationMessage: String? {
        guard let totalTips = parsedTotalTips else {
            return "Enter total tips before calculating."
        }

        guard let bartenders = parsedBartenders() else {
            return "Check each bartender's food sales and hours."
        }

        guard !bartenders.isEmpty else {
            return "Add at least one bartender with hours greater than 0."
        }

        guard let barbacks = parsedBarbacks() else {
            return "Check each barback's hours."
        }

        let runnerTipOut = TipCalculator.foodRunnerTipOut(
            combinedFoodSales: bartenders.reduce(Decimal(0)) { $0 + $1.foodSales },
            hasFoodRunners: !foodRunners.isEmpty
        )

        if totalTips - runnerTipOut < Decimal(0) {
            return "Total tips need to cover the food runner tip-out."
        }

        if barbacks.contains(where: { $0.hours <= Decimal(0) }) {
            return "Every added barback needs hours greater than 0."
        }

        return nil
    }

    var calculationResult: TipCalculator.Result? {
        guard canCalculate,
              let totalTips = parsedTotalTips,
              let bartenders = parsedBartenders(),
              let barbacks = parsedBarbacks()
        else {
            return nil
        }

        return TipCalculator.calculate(
            totalTips: totalTips,
            bartenders: bartenders,
            barbacks: barbacks,
            foodRunnerCount: foodRunners.count
        )
    }

    func addBartender() {
        bartenders.append(CrewMember())
    }

    func removeBartender(at index: Int) {
        guard bartenders.indices.contains(index) else { return }
        bartenders.remove(at: index)
    }

    func addBarback() {
        barbacks.append(CrewMember())
    }

    func removeBarback(at index: Int) {
        guard barbacks.indices.contains(index) else { return }
        barbacks.remove(at: index)
    }

    func addFoodRunner() {
        foodRunners.append(FoodRunner())
    }

    func removeFoodRunner(at index: Int) {
        guard foodRunners.indices.contains(index) else { return }
        foodRunners.remove(at: index)
    }

    func resetAllEntries() {
        clearEntries(for: Date())
    }

    func resetIfNeededForNewDay(now: Date = Date()) {
        let today = Self.dateKey(for: now)

        if storedDateKey != today {
            clearEntries(for: now)
        }
    }

    private func parsedBartenders() -> [TipCalculator.BartenderInput]? {
        var inputs: [TipCalculator.BartenderInput] = []

        for (index, bartender) in bartenders.enumerated() {
            guard let foodSales = bartender.foodSalesValue,
                  let hours = bartender.hoursValue,
                  hours > Decimal(0)
            else {
                return nil
            }

            inputs.append(
                TipCalculator.BartenderInput(
                    id: bartender.id,
                    name: bartender.displayName(defaultName: "Bartender \(index + 1)"),
                    foodSales: foodSales,
                    hours: hours
                )
            )
        }

        return inputs
    }

    private func parsedBarbacks() -> [TipCalculator.BarbackInput]? {
        var inputs: [TipCalculator.BarbackInput] = []

        for (index, barback) in barbacks.enumerated() {
            guard let hours = barback.hoursValue, hours > Decimal(0) else {
                return nil
            }

            inputs.append(
                TipCalculator.BarbackInput(
                    id: barback.id,
                    name: barback.displayName(defaultName: "Barback \(index + 1)"),
                    hours: hours
                )
            )
        }

        return inputs
    }

    private func clearEntries(for date: Date) {
        isRestoring = true
        storedDateKey = Self.dateKey(for: date)
        totalTipsText = ""
        bartenders = []
        barbacks = []
        foodRunners = []
        isRestoring = false
        save()
    }

    private func loadStoredNight() {
        guard let data = defaults.data(forKey: storageKey),
              let storedNight = try? JSONDecoder().decode(StoredNight.self, from: data)
        else {
            return
        }

        isRestoring = true
        storedDateKey = storedNight.dateKey
        totalTipsText = storedNight.totalTipsText
        bartenders = storedNight.bartenders
        barbacks = storedNight.barbacks
        foodRunners = storedNight.foodRunners
        isRestoring = false
    }

    private func saveIfReady() {
        guard !isRestoring else { return }
        save()
    }

    private func save() {
        let storedNight = StoredNight(
            dateKey: storedDateKey,
            totalTipsText: totalTipsText,
            bartenders: bartenders,
            barbacks: barbacks,
            foodRunners: foodRunners
        )

        guard let data = try? JSONEncoder().encode(storedNight) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

struct TipCalculator {
    struct BartenderInput: Identifiable {
        let id: UUID
        let name: String
        let foodSales: Decimal
        let hours: Decimal
    }

    struct BarbackInput: Identifiable {
        let id: UUID
        let name: String
        let hours: Decimal
    }

    struct PersonPayout: Identifiable {
        let id: UUID
        let name: String
        let hours: Decimal
        let takeHome: Decimal
    }

    struct Result {
        let totalTips: Decimal
        let combinedFoodSales: Decimal
        let foodRunnerTipOut: Decimal
        let hasFoodRunnerTipOut: Bool
        let truePooledTips: Decimal
        let bartenderPool: Decimal
        let bartenderHourlyRate: Decimal
        let bartenderPayouts: [PersonPayout]
        let barbackPool: Decimal
        let barbackHourlyRate: Decimal
        let barbackPayouts: [PersonPayout]
        let bartenderRoundingOverage: Decimal
        let barbackRoundingOverage: Decimal
        let overage: Decimal
    }

    static func calculate(
        totalTips: Decimal,
        bartenders: [BartenderInput],
        barbacks: [BarbackInput],
        foodRunnerCount: Int
    ) -> Result {
        let combinedFoodSales = bartenders.reduce(Decimal(0)) { $0 + $1.foodSales }
        let foodRunnerTipOut = foodRunnerTipOut(
            combinedFoodSales: combinedFoodSales,
            hasFoodRunners: foodRunnerCount > 0
        )
        let truePooledTips = totalTips - foodRunnerTipOut
        let barbackPool = barbacks.isEmpty ? Decimal(0) : roundHalfUpWhole(truePooledTips * (Decimal(15) / Decimal(100)))
        let bartenderPool = truePooledTips - barbackPool

        let totalBartenderHours = bartenders.reduce(Decimal(0)) { $0 + $1.hours }
        let bartenderHourlyRate = totalBartenderHours > Decimal(0) ? bartenderPool / totalBartenderHours : Decimal(0)
        let bartenderPayouts = bartenders.map { bartender in
            PersonPayout(
                id: bartender.id,
                name: bartender.name,
                hours: bartender.hours,
                takeHome: roundDownWhole(bartender.hours * bartenderHourlyRate)
            )
        }

        let totalBarbackHours = barbacks.reduce(Decimal(0)) { $0 + $1.hours }
        let barbackHourlyRate = totalBarbackHours > Decimal(0) ? barbackPool / totalBarbackHours : Decimal(0)
        let barbackPayouts = barbacks.map { barback in
            PersonPayout(
                id: barback.id,
                name: barback.name,
                hours: barback.hours,
                takeHome: roundDownWhole(barback.hours * barbackHourlyRate)
            )
        }

        let bartenderTakeHomeTotal = bartenderPayouts.reduce(Decimal(0)) { $0 + $1.takeHome }
        let barbackTakeHomeTotal = barbackPayouts.reduce(Decimal(0)) { $0 + $1.takeHome }
        let bartenderRoundingOverage = nonNegative(bartenderPool - bartenderTakeHomeTotal)
        let barbackRoundingOverage = nonNegative(barbackPool - barbackTakeHomeTotal)

        return Result(
            totalTips: totalTips,
            combinedFoodSales: combinedFoodSales,
            foodRunnerTipOut: foodRunnerTipOut,
            hasFoodRunnerTipOut: foodRunnerCount > 0,
            truePooledTips: truePooledTips,
            bartenderPool: bartenderPool,
            bartenderHourlyRate: bartenderHourlyRate,
            bartenderPayouts: bartenderPayouts,
            barbackPool: barbackPool,
            barbackHourlyRate: barbackHourlyRate,
            barbackPayouts: barbackPayouts,
            bartenderRoundingOverage: bartenderRoundingOverage,
            barbackRoundingOverage: barbackRoundingOverage,
            overage: bartenderRoundingOverage + barbackRoundingOverage
        )
    }

    static func foodRunnerTipOut(combinedFoodSales: Decimal, hasFoodRunners: Bool) -> Decimal {
        guard hasFoodRunners else { return Decimal(0) }
        return roundHalfUpWhole(combinedFoodSales * (Decimal(4) / Decimal(100)))
    }

    static func roundHalfUpWhole(_ value: Decimal) -> Decimal {
        round(value, scale: 0, mode: .plain)
    }

    static func roundDownWhole(_ value: Decimal) -> Decimal {
        round(value, scale: 0, mode: .down)
    }

    private static func round(_ value: Decimal, scale: Int16, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        let handler = NSDecimalNumberHandler(
            roundingMode: mode,
            scale: scale,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )

        return NSDecimalNumber(decimal: value).rounding(accordingToBehavior: handler).decimalValue
    }

    private static func nonNegative(_ value: Decimal) -> Decimal {
        value < Decimal(0) ? Decimal(0) : value
    }
}

enum ShiftHours {
    static func hoursBetween(start: Date, end: Date, calendar: Calendar = .current) -> Decimal? {
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        let startMinutes = ((startComponents.hour ?? 0) * 60) + (startComponents.minute ?? 0)
        let endMinutes = ((endComponents.hour ?? 0) * 60) + (endComponents.minute ?? 0)
        let minuteDifference = endMinutes - startMinutes

        guard minuteDifference > 0 else { return nil }
        return Decimal(minuteDifference) / Decimal(60)
    }
}

enum AppFormat {
    static func parseDecimal(_ text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmed

        guard !normalized.isEmpty,
              let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              decimal >= Decimal(0)
        else {
            return nil
        }

        return decimal
    }

    static func money(_ value: Decimal) -> String {
        let isWholeDollar = value == TipCalculator.roundDownWhole(value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = isWholeDollar ? 0 : 2
        formatter.maximumFractionDigits = isWholeDollar ? 0 : 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$\(value)"
    }

    static func rate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        let formatted = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
        return "$\(formatted)/hr"
    }

    static func hours(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ContentView()
        .environmentObject(TipOutViewModel())
}
