import SwiftUI

struct DateSelectionView: View {
    @Binding var selectedDate: Date
    let viewModel: LakeStationsViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @Namespace private var animation
    
    // Verfügbare Tage (heute + 6 Tage)
    private var availableDates: [Date] {
        (0...6).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))
        }
    }
    
    private var selectedIndex: Int {
        availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pill Navigation
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(availableDates.enumerated()), id: \.offset) { index, date in
                            DatePillView(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isToday: Calendar.current.isDateInToday(date),
                                namespace: animation
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectDate(date)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 32)
                }
                .padding(.horizontal, 16)
                .onChange(of: selectedDate) { oldValue, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
                .onAppear {
                    // Initial scroll to selected date
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
            }
            .frame(height: 88)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        let threshold: CGFloat = 50
                        
                        if value.translation.width < -threshold {
                            // Swipe left -> next day
                            if selectedIndex < availableDates.count - 1 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectDate(availableDates[selectedIndex + 1])
                                }
                            }
                        } else if value.translation.width > threshold {
                            // Swipe right -> previous day
                            if selectedIndex > 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectDate(availableDates[selectedIndex - 1])
                }
            }
        }
                        
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .onChange(of: viewModel.selectedDate) { oldValue, newValue in
            if selectedDate != newValue {
                selectedDate = newValue
            }
        }
    }
    
    private func selectDate(_ date: Date) {
        selectedDate = date
        viewModel.selectedDate = date
        scheduleViewModel.selectedDate = date
        
        // Haptic Feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            await viewModel.refreshDepartures()
        }
    }
}

// MARK: - Date Pill View
struct DatePillView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let namespace: Namespace.ID
    
    private var displayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        
        if isToday {
            formatter.dateFormat = "d MMM"
            return "Today, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "EEE, d MMM"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : Color("text-color"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "pill", in: namespace)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                    } else {
                        Capsule()
                            .fill(Color("text-color").opacity(0.05))
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isToday && !isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}