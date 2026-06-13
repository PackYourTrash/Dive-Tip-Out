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
    @State private var currentWilfredQuote: WilfredQuote?

    var body: some View {
        NavigationStack {
            ZStack {
                OceanBackground()

                VStack(spacing: 28) {
                    Spacer(minLength: 36)

                    VStack(spacing: 18) {
                        AnimatedWaveIcon()

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
                    .homeFrostedCard()
                    .padding(.horizontal, 24)

                    Spacer(minLength: 56)
                }

                VStack {
                    HStack {
                        Spacer()

                        Button("wilfred") {
                            showNewWilfredQuote()
                        }
                        .buttonStyle(WilfredButtonStyle())
                    }

                    Spacer()
                }
                .padding(.top, 14)
                .padding(.trailing, 18)

                if let currentWilfredQuote {
                    WilfredQuotePopup(
                        quote: currentWilfredQuote,
                        onNext: showNewWilfredQuote,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                self.currentWilfredQuote = nil
                            }
                        }
                    )
                    .zIndex(2)
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
            Text("This clears the total tips, bartenders, barbacks, and food runner option.")
        }
    }

    private func showNewWilfredQuote() {
        let availableQuotes = WilfredQuote.all.filter { $0.id != currentWilfredQuote?.id }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            currentWilfredQuote = availableQuotes.randomElement() ?? WilfredQuote.all.randomElement()
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

                        Text(roundingSummary(for: result))
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

    private func roundingSummary(for result: TipCalculator.Result) -> String {
        var messages: [String] = []

        if result.bartenderRoundingShortage > Decimal(0) {
            messages.append(
                shortageMessage(
                    role: "Bartender",
                    shortage: result.bartenderRoundingShortage,
                    unresolvedShortage: result.bartenderUnresolvedRoundingShortage,
                    adjustments: result.bartenderShortageAdjustments
                )
            )
        }

        if result.barbackRoundingShortage > Decimal(0) {
            messages.append(
                shortageMessage(
                    role: "Barback",
                    shortage: result.barbackRoundingShortage,
                    unresolvedShortage: result.barbackUnresolvedRoundingShortage,
                    adjustments: result.barbackShortageAdjustments
                )
            )
        }

        if result.overage > Decimal(0) {
            messages.append("Overage: \(AppFormat.money(result.overage)) (\(AppFormat.money(result.bartenderRoundingOverage)) from bartender rounding + \(AppFormat.money(result.barbackRoundingOverage)) from barback rounding) - hand out as you choose.")
        }

        if messages.isEmpty {
            return "Rounding is flush: payouts match their pools."
        }

        if result.unresolvedShortage == Decimal(0), result.overage == Decimal(0) {
            messages.append("Final payouts are flush.")
        }

        return messages.joined(separator: " ")
    }

    private func shortageMessage(
        role: String,
        shortage: Decimal,
        unresolvedShortage: Decimal,
        adjustments: [TipCalculator.RoundingAdjustment]
    ) -> String {
        if adjustments.isEmpty {
            return "\(role) shortage: \(AppFormat.money(shortage)); no rounded-up payout was available to pull from."
        }

        let adjustedNames = formattedNameList(adjustments.map(\.name))
        let action = "rounding \(adjustedNames) down"

        if unresolvedShortage > Decimal(0) {
            return "\(role) shortage: \(AppFormat.money(shortage)) reduced by \(action); \(AppFormat.money(unresolvedShortage)) still short."
        }

        return "\(role) shortage: \(AppFormat.money(shortage)) covered by \(action)."
    }

    private func formattedNameList(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let leadingNames = names.dropLast().joined(separator: ", ")
            return "\(leadingNames), and \(names[names.count - 1])"
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
            SectionTitle("Food Runner")

            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.hasFoodRunner },
                        set: { viewModel.setFoodRunnerOption($0) }
                    )
                ) {
                    Label("Food runner worked", systemImage: "figure.run")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .tint(Color(red: 0.20, green: 0.72, blue: 0.86))

                if viewModel.hasFoodRunner {
                    Text("Food runner tip-out will calculate from bartender food sales.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .glassCard()
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
    @State private var expandedField: TimePickerField?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimePickerToggleRow(
                title: "Start",
                systemImage: "sunrise",
                date: member.startTime,
                isExpanded: expandedField == .start
            ) {
                toggleField(.start)
            }

            if expandedField == .start {
                WheelTimePicker(date: $member.startTime, minuteInterval: 5)
                    .timeWheelStyle()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TimePickerToggleRow(
                title: "End",
                systemImage: "moon",
                date: member.endTime,
                isExpanded: expandedField == .end
            ) {
                toggleField(.end)
            }

            if expandedField == .end {
                WheelTimePicker(date: $member.endTime, minuteInterval: 5)
                    .timeWheelStyle()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let hours = member.hoursValue {
                Label("\(AppFormat.hours(hours)) hours", systemImage: "clock")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: expandedField)
    }

    private func toggleField(_ field: TimePickerField) {
        expandedField = expandedField == field ? nil : field
    }
}

private enum TimePickerField: Equatable {
    case start
    case end
}

struct TimePickerToggleRow: View {
    let title: String
    let systemImage: String
    let date: Date
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 22)

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 12)

                Text(AppFormat.time(date))
                    .font(.headline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(Color(red: 0.04, green: 0.18, blue: 0.26))
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WheelTimePicker: UIViewRepresentable {
    @Binding var date: Date
    let minuteInterval: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = minuteInterval
        picker.locale = Locale(identifier: "en_US")
        picker.overrideUserInterfaceStyle = .light
        picker.backgroundColor = .clear
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.dateChanged(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.date = $date

        if picker.minuteInterval != minuteInterval {
            picker.minuteInterval = minuteInterval
        }

        if abs(picker.date.timeIntervalSince(date)) > 0.5 {
            picker.setDate(date, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    final class Coordinator: NSObject {
        var date: Binding<Date>

        init(date: Binding<Date>) {
            self.date = date
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            date.wrappedValue = sender.date
        }
    }
}

struct WilfredQuotePopup: View {
    let quote: WilfredQuote
    let onNext: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Spacer()

                    Button(action: onNext) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.diveBlue)
                    .accessibilityLabel("New quote")

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.88))
                    .accessibilityLabel("Close")
                }

                quoteText
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\u{2014} \(quote.author)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.24), radius: 28, y: 18)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var quoteText: Text {
        guard let range = quote.text.range(
            of: quote.highlight,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) else {
            return Text("\u{201C}\(quote.text)\u{201D}")
                .font(.title3)
        }

        let leadingText = String(quote.text[..<range.lowerBound])
        let highlightedText = String(quote.text[range])
        let trailingText = String(quote.text[range.upperBound...])
        let leading = Text("\u{201C}\(leadingText)").font(.title3)
        let highlighted = Text(highlightedText).font(.title3.weight(.bold))
        let trailing = Text("\(trailingText)\u{201D}").font(.title3)
        return leading + highlighted + trailing
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

struct AnimatedWaveIcon: View {
    @State private var crestIsHigh = false
    @State private var swellIsWide = false

    var body: some View {
        ZStack {
            Image(systemName: "water.waves")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(.white.opacity(swellIsWide ? 0.18 : 0.10))
                .blur(radius: 9)
                .scaleEffect(swellIsWide ? 1.14 : 0.94)

            Image(systemName: "water.waves")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(crestIsHigh ? 2.5 : -2.5))
                .offset(x: crestIsHigh ? 3 : -3, y: crestIsHigh ? -3 : 3)
                .shadow(color: AppColor.diveBlue.opacity(0.36), radius: 12, y: 7)

            Image(systemName: "water.waves")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(AppColor.diveBlue.opacity(0.58))
                .offset(x: crestIsHigh ? 10 : -10, y: crestIsHigh ? 4 : -2)
                .opacity(swellIsWide ? 0.56 : 0.82)
                .blendMode(.screen)
        }
        .frame(width: 92, height: 72)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                crestIsHigh = true
            }

            withAnimation(.easeInOut(duration: 2.35).repeatForever(autoreverses: true)) {
                swellIsWide = true
            }
        }
    }
}

enum AppColor {
    static let diveBlue = Color(red: 0.20, green: 0.72, blue: 0.86)
}

struct WilfredButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColor.diveBlue)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .background(
                Capsule(style: .continuous)
                    .fill(.black.opacity(configuration.isPressed ? 0.78 : 0.62))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
    func homeFrostedCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.46), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
                    .blur(radius: 1.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.16), radius: 28, y: 18)
    }

    func glassCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
            )
    }

    func timeWheelStyle() -> some View {
        self
            .frame(height: 150)
            .clipped()
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

struct WilfredQuote: Identifiable, Equatable {
    let season: Int
    let episode: Int
    let text: String
    let highlight: String
    let author: String

    var id: String {
        "\(season)-\(episode)"
    }

    static let all: [WilfredQuote] = [
        WilfredQuote(season: 1, episode: 1, text: "Sanity and happiness are an impossible combination.", highlight: "happiness", author: "Mark Twain"),
        WilfredQuote(season: 1, episode: 2, text: "Trust thyself only, and another shall not betray thee.", highlight: "Trust", author: "Thomas Fuller"),
        WilfredQuote(season: 1, episode: 3, text: "Fear has its uses but cowardice has none.", highlight: "Fear", author: "Mahatma Ghandi"),
        WilfredQuote(season: 1, episode: 4, text: "Happiness can exist only in acceptance.", highlight: "acceptance", author: "George Orwell"),
        WilfredQuote(season: 1, episode: 5, text: "Seek respect mainly from thyself, for it comes first from within.", highlight: "respect", author: "Steven H. Coogler"),
        WilfredQuote(season: 1, episode: 6, text: "Conscience is the dog that can't bite, but never stops barking.", highlight: "Conscience", author: "Proverb"),
        WilfredQuote(season: 1, episode: 7, text: "In general, pride is at the bottom of all great mistakes.", highlight: "pride", author: "Steven H. Coogler"),
        WilfredQuote(season: 1, episode: 8, text: "Anger as soon as fed is dead -- tis starving makes it fat.", highlight: "Anger", author: "Emily Dickinson"),
        WilfredQuote(season: 1, episode: 9, text: "Make no judgements where you have no compassion.", highlight: "compassion", author: "Anne McCaffrey"),
        WilfredQuote(season: 1, episode: 10, text: "Isolation is a self-defeating dream.", highlight: "Isolation", author: "Carlos Salinas de Gortari"),
        WilfredQuote(season: 1, episode: 11, text: "Doubt must be no more than vigilance, otherwise it can become dangerous.", highlight: "Doubt", author: "George C. Lichtenberg"),
        WilfredQuote(season: 1, episode: 12, text: "Love is a willingness to sacrifice.", highlight: "sacrifice", author: "Michael Novak"),
        WilfredQuote(season: 1, episode: 13, text: "The value of identity is that so often with it comes purpose.", highlight: "identity", author: "Richard R. Grant"),
        WilfredQuote(season: 2, episode: 1, text: "Discontent is the first necessity of progress.", highlight: "progress", author: "Thomas Edison"),
        WilfredQuote(season: 2, episode: 2, text: "Some of us think holding on makes us strong, but sometimes it is letting go.", highlight: "letting go", author: "Herman Hesse"),
        WilfredQuote(season: 2, episode: 3, text: "Let not a man guard his dignity but let his dignity guard him.", highlight: "dignity", author: "Ralph Waldo Emerson"),
        WilfredQuote(season: 2, episode: 4, text: "Guilt: the gift that keeps on giving.", highlight: "Guilt", author: "Erma Bombeck"),
        WilfredQuote(season: 2, episode: 5, text: "Be here now.", highlight: "now", author: "Ram Dass"),
        WilfredQuote(season: 2, episode: 6, text: "The master understands that the universe is forever out of control.", highlight: "control", author: "Lao Tzu"),
        WilfredQuote(season: 2, episode: 7, text: "Our biggest problems arise from the avoidance of smaller ones.", highlight: "avoidance", author: "Jeremy Caulfield"),
        WilfredQuote(season: 2, episode: 8, text: "The truth will set you free, but first it will make you miserable.", highlight: "truth", author: "James A. Garfield"),
        WilfredQuote(season: 2, episode: 9, text: "The thing that lies at the foundation of positive change is service to a fellow human being.", highlight: "service", author: "Lee Iacocca"),
        WilfredQuote(season: 2, episode: 10, text: "Honesty and transparency make you vulnerable. Be honest and transparent anyway.", highlight: "Honesty", author: "Mother Teresa"),
        WilfredQuote(season: 2, episode: 11, text: "If you do not ask the right questions, you do not get the right answers.", highlight: "questions", author: "Edward Hodnett"),
        WilfredQuote(season: 2, episode: 12, text: "Resentment is like taking poison and waiting for the other person to die.", highlight: "Resentment", author: "Malachy McCourt"),
        WilfredQuote(season: 2, episode: 13, text: "If we knew each other's secrets, what comfort should we find.", highlight: "secrets", author: "John Churton Collins"),
        WilfredQuote(season: 3, episode: 1, text: "The mistake is thinking that there can be an antidote to the uncertainty.", highlight: "uncertainty", author: "David Levithan"),
        WilfredQuote(season: 3, episode: 2, text: "Cure sometimes, treat often, comfort always.", highlight: "comfort", author: "Hippocrates"),
        WilfredQuote(season: 3, episode: 3, text: "Suspicion is a heavy armor and with its weight it impedes more than it protects.", highlight: "Suspicion", author: "Robert Burns"),
        WilfredQuote(season: 3, episode: 4, text: "Sincerity, even if it speaks with a stutter, will sound eloquent when inspired.", highlight: "Sincerity", author: "Eiji Yoshikawa"),
        WilfredQuote(season: 3, episode: 5, text: "I have little shame, no dignity - all in the name of a better cause.", highlight: "shame", author: "A.J. Jacobs"),
        WilfredQuote(season: 3, episode: 6, text: "Truth may sometimes hurt, but delusion harms.", highlight: "delusion", author: "Vanna Bonta"),
        WilfredQuote(season: 3, episode: 7, text: "Intuition is more important to discovery than logic.", highlight: "Intuition", author: "Henri Poincare"),
        WilfredQuote(season: 3, episode: 8, text: "How weird was it to drive streets I knew so well. What a different perspective.", highlight: "perspective", author: "Suzanne Vega"),
        WilfredQuote(season: 3, episode: 9, text: "There can be no progress without head-on confrontation.", highlight: "confrontation", author: "Christopher Hitchens"),
        WilfredQuote(season: 3, episode: 10, text: "Sometimes it's necessary to go a long distance out of the way to come back a short distance correctly.", highlight: "distance", author: "Edward Albee"),
        WilfredQuote(season: 3, episode: 11, text: "Stagnation is death. If you don't change, you die. It's that simple. It's that scary.", highlight: "Stagnation", author: "Leonard Sweet"),
        WilfredQuote(season: 3, episode: 12, text: "In my opinion, actual heroism, like actual love, is a messy, painful, vulnerable business.", highlight: "heroism", author: "John Green"),
        WilfredQuote(season: 3, episode: 13, text: "Maybe all one can do is hope to end up with the right regrets.", highlight: "regrets", author: "Arthur Miller"),
        WilfredQuote(season: 4, episode: 1, text: "If you have behaved badly, repent, make what amends you can and address yourself to the task of behaving better next time.", highlight: "amends", author: "Aldous Huxley"),
        WilfredQuote(season: 4, episode: 2, text: "Sooner or later everyone sits down to a banquet of consequences.", highlight: "consequences", author: "Robert Louis Stevenson"),
        WilfredQuote(season: 4, episode: 3, text: "We are all in the same boat, in a stormy sea, and we owe each other a terrible loyalty.", highlight: "loyalty", author: "G.K. Chesterton"),
        WilfredQuote(season: 4, episode: 4, text: "In our quest for the answers of life we tend to make order out of chaos, and chaos out of order.", highlight: "answers", author: "Jeffery Fry"),
        WilfredQuote(season: 4, episode: 5, text: "There are many ways of going forward, but only one way of standing still.", highlight: "forward", author: "Franklin D. Roosevelt"),
        WilfredQuote(season: 4, episode: 6, text: "Truth is outside of all patterns.", highlight: "patterns", author: "Bruce Lee"),
        WilfredQuote(season: 4, episode: 7, text: "By imposing too great a responsibility, or rather, all responsibility, on yourself, you crush yourself.", highlight: "responsibility", author: "Franz Kafka"),
        WilfredQuote(season: 4, episode: 8, text: "How few there are who have courage enough to own their faults, or resolution enough to mend them.", highlight: "courage", author: "Benjamin Franklin"),
        WilfredQuote(season: 4, episode: 9, text: "Resistance is useless.", highlight: "Resistance", author: "Dr. Who"),
        WilfredQuote(season: 4, episode: 10, text: "Happiness does not depend on outward things, but on the way we see them.", highlight: "Happiness", author: "Leo Tolstoy")
    ]
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
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }

    private static func defaultEndTime() -> Date {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

struct StoredNight: Codable {
    var dateKey: String
    var totalTipsText: String
    var bartenders: [CrewMember]
    var barbacks: [CrewMember]
    var hasFoodRunner: Bool
    var foodRunnerWasManuallySet: Bool

    init(
        dateKey: String,
        totalTipsText: String,
        bartenders: [CrewMember],
        barbacks: [CrewMember],
        hasFoodRunner: Bool,
        foodRunnerWasManuallySet: Bool
    ) {
        self.dateKey = dateKey
        self.totalTipsText = totalTipsText
        self.bartenders = bartenders
        self.barbacks = barbacks
        self.hasFoodRunner = hasFoodRunner
        self.foodRunnerWasManuallySet = foodRunnerWasManuallySet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        totalTipsText = try container.decode(String.self, forKey: .totalTipsText)
        bartenders = try container.decode([CrewMember].self, forKey: .bartenders)
        barbacks = try container.decode([CrewMember].self, forKey: .barbacks)

        let storedFoodRunnerChoice = try container.decodeIfPresent(Bool.self, forKey: .hasFoodRunner) ?? true
        foodRunnerWasManuallySet = try container.decodeIfPresent(Bool.self, forKey: .foodRunnerWasManuallySet) ?? false
        hasFoodRunner = foodRunnerWasManuallySet ? storedFoodRunnerChoice : true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateKey, forKey: .dateKey)
        try container.encode(totalTipsText, forKey: .totalTipsText)
        try container.encode(bartenders, forKey: .bartenders)
        try container.encode(barbacks, forKey: .barbacks)
        try container.encode(hasFoodRunner, forKey: .hasFoodRunner)
        try container.encode(foodRunnerWasManuallySet, forKey: .foodRunnerWasManuallySet)
    }

    private enum CodingKeys: String, CodingKey {
        case dateKey
        case totalTipsText
        case bartenders
        case barbacks
        case hasFoodRunner
        case foodRunnerWasManuallySet
    }
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

    @Published var hasFoodRunner = true {
        didSet { saveIfReady() }
    }

    @Published private var foodRunnerWasManuallySet = false {
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
            hasFoodRunner: hasFoodRunner
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
            hasFoodRunner: hasFoodRunner
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

    func setFoodRunnerOption(_ isOn: Bool) {
        foodRunnerWasManuallySet = true
        hasFoodRunner = isOn
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
        hasFoodRunner = true
        foodRunnerWasManuallySet = false
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
        hasFoodRunner = storedNight.hasFoodRunner
        foodRunnerWasManuallySet = storedNight.foodRunnerWasManuallySet
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
            hasFoodRunner: hasFoodRunner,
            foodRunnerWasManuallySet: foodRunnerWasManuallySet
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

    struct RoundingAdjustment: Identifiable {
        let id: UUID
        let name: String
        let amount: Decimal
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
        let bartenderRoundingShortage: Decimal
        let barbackRoundingShortage: Decimal
        let bartenderUnresolvedRoundingShortage: Decimal
        let barbackUnresolvedRoundingShortage: Decimal
        let shortage: Decimal
        let unresolvedShortage: Decimal
        let bartenderShortageAdjustments: [RoundingAdjustment]
        let barbackShortageAdjustments: [RoundingAdjustment]
        let bartenderRoundingOverage: Decimal
        let barbackRoundingOverage: Decimal
        let overage: Decimal
    }

    private struct PayoutDraft {
        let id: UUID
        let name: String
        let hours: Decimal
        let exactTakeHome: Decimal
    }

    private struct PayoutCandidate {
        let id: UUID
        let name: String
        let hours: Decimal
        var takeHome: Decimal
        let cents: Decimal
        let wasRoundedUp: Bool
        let originalIndex: Int
    }

    private struct RoundedPayoutDetail {
        let takeHome: Decimal
        let cents: Decimal
        let wasRoundedUp: Bool
    }

    private struct ReconciledPayouts {
        let payouts: [PersonPayout]
        let shortage: Decimal
        let unresolvedShortage: Decimal
        let overage: Decimal
        let shortageAdjustments: [RoundingAdjustment]
    }

    static func calculate(
        totalTips: Decimal,
        bartenders: [BartenderInput],
        barbacks: [BarbackInput],
        hasFoodRunner: Bool
    ) -> Result {
        let combinedFoodSales = bartenders.reduce(Decimal(0)) { $0 + $1.foodSales }
        let foodRunnerTipOut = foodRunnerTipOut(
            combinedFoodSales: combinedFoodSales,
            hasFoodRunner: hasFoodRunner
        )
        let truePooledTips = totalTips - foodRunnerTipOut
        let barbackPool = barbacks.isEmpty ? Decimal(0) : roundHalfUpWhole(truePooledTips * (Decimal(15) / Decimal(100)))
        let bartenderPool = truePooledTips - barbackPool

        let totalBartenderHours = bartenders.reduce(Decimal(0)) { $0 + $1.hours }
        let bartenderHourlyRate = totalBartenderHours > Decimal(0) ? bartenderPool / totalBartenderHours : Decimal(0)
        let bartenderReconciliation = reconciledPayouts(
            pool: bartenderPool,
            drafts: bartenders.map { bartender in
                PayoutDraft(
                    id: bartender.id,
                    name: bartender.name,
                    hours: bartender.hours,
                    exactTakeHome: bartender.hours * bartenderHourlyRate
                )
            }
        )

        let totalBarbackHours = barbacks.reduce(Decimal(0)) { $0 + $1.hours }
        let barbackHourlyRate = totalBarbackHours > Decimal(0) ? barbackPool / totalBarbackHours : Decimal(0)
        let barbackReconciliation = reconciledPayouts(
            pool: barbackPool,
            drafts: barbacks.map { barback in
                PayoutDraft(
                    id: barback.id,
                    name: barback.name,
                    hours: barback.hours,
                    exactTakeHome: barback.hours * barbackHourlyRate
                )
            }
        )

        return Result(
            totalTips: totalTips,
            combinedFoodSales: combinedFoodSales,
            foodRunnerTipOut: foodRunnerTipOut,
            hasFoodRunnerTipOut: hasFoodRunner,
            truePooledTips: truePooledTips,
            bartenderPool: bartenderPool,
            bartenderHourlyRate: bartenderHourlyRate,
            bartenderPayouts: bartenderReconciliation.payouts,
            barbackPool: barbackPool,
            barbackHourlyRate: barbackHourlyRate,
            barbackPayouts: barbackReconciliation.payouts,
            bartenderRoundingShortage: bartenderReconciliation.shortage,
            barbackRoundingShortage: barbackReconciliation.shortage,
            bartenderUnresolvedRoundingShortage: bartenderReconciliation.unresolvedShortage,
            barbackUnresolvedRoundingShortage: barbackReconciliation.unresolvedShortage,
            shortage: bartenderReconciliation.shortage + barbackReconciliation.shortage,
            unresolvedShortage: bartenderReconciliation.unresolvedShortage + barbackReconciliation.unresolvedShortage,
            bartenderShortageAdjustments: bartenderReconciliation.shortageAdjustments,
            barbackShortageAdjustments: barbackReconciliation.shortageAdjustments,
            bartenderRoundingOverage: bartenderReconciliation.overage,
            barbackRoundingOverage: barbackReconciliation.overage,
            overage: bartenderReconciliation.overage + barbackReconciliation.overage
        )
    }

    private static func reconciledPayouts(pool: Decimal, drafts: [PayoutDraft]) -> ReconciledPayouts {
        var candidates = drafts.enumerated().map { index, draft in
            let roundedDetail = roundedPayoutDetail(draft.exactTakeHome)

            return PayoutCandidate(
                id: draft.id,
                name: draft.name,
                hours: draft.hours,
                takeHome: roundedDetail.takeHome,
                cents: roundedDetail.cents,
                wasRoundedUp: roundedDetail.wasRoundedUp,
                originalIndex: index
            )
        }

        let initialTakeHomeTotal = candidates.reduce(Decimal(0)) { $0 + $1.takeHome }
        let shortage = nonNegative(initialTakeHomeTotal - pool)
        var remainingShortage = shortage
        var shortageAdjustments: [RoundingAdjustment] = []
        let roundedUpCandidateIndices = candidates.indices
            .filter { candidates[$0].wasRoundedUp }
            .sorted { leftIndex, rightIndex in
                let left = candidates[leftIndex]
                let right = candidates[rightIndex]

                if left.cents == right.cents {
                    return left.originalIndex < right.originalIndex
                }

                return left.cents < right.cents
            }

        for index in roundedUpCandidateIndices {
            guard remainingShortage > Decimal(0) else { break }

            candidates[index].takeHome -= Decimal(1)
            remainingShortage -= Decimal(1)
            shortageAdjustments.append(
                RoundingAdjustment(
                    id: candidates[index].id,
                    name: candidates[index].name,
                    amount: Decimal(1)
                )
            )
        }

        let finalTakeHomeTotal = candidates.reduce(Decimal(0)) { $0 + $1.takeHome }
        let payouts = candidates.map { candidate in
            PersonPayout(
                id: candidate.id,
                name: candidate.name,
                hours: candidate.hours,
                takeHome: candidate.takeHome
            )
        }

        return ReconciledPayouts(
            payouts: payouts,
            shortage: shortage,
            unresolvedShortage: nonNegative(finalTakeHomeTotal - pool),
            overage: nonNegative(pool - finalTakeHomeTotal),
            shortageAdjustments: shortageAdjustments
        )
    }

    static func foodRunnerTipOut(combinedFoodSales: Decimal, hasFoodRunner: Bool) -> Decimal {
        guard hasFoodRunner else { return Decimal(0) }
        return roundHalfUpWhole(combinedFoodSales * (Decimal(4) / Decimal(100)))
    }

    static func roundHalfUpWhole(_ value: Decimal) -> Decimal {
        round(value, scale: 0, mode: .plain)
    }

    static func roundDownWhole(_ value: Decimal) -> Decimal {
        round(value, scale: 0, mode: .down)
    }

    static func roundPayoutWhole(_ value: Decimal) -> Decimal {
        roundedPayoutDetail(value).takeHome
    }

    private static func roundedPayoutDetail(_ value: Decimal) -> RoundedPayoutDetail {
        let valueRoundedToCents = round(value, scale: 2, mode: .plain)
        let wholeDollars = roundDownWhole(valueRoundedToCents)
        let cents = valueRoundedToCents - wholeDollars
        let takeHome = cents > Decimal(50) / Decimal(100)
            ? wholeDollars + Decimal(1)
            : wholeDollars

        return RoundedPayoutDetail(
            takeHome: takeHome,
            cents: cents,
            wasRoundedUp: takeHome > wholeDollars
        )
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

    static func time(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: value)
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
