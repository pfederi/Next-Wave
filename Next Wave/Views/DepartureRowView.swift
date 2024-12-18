import SwiftUI

struct DepartureRowView: View {
    let journey: Journey
    let index: Int
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    @Binding var notifiedJourneys: Set<String>
    let scheduleViewModel: ScheduleViewModel
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            TimeColumn(formattedTime: formattedTime, 
                      isPast: isPast, 
                      isCurrentDay: isCurrentDay)
            
            Spacer().frame(width: 16)
            
            InfoColumn(journey: journey, 
                      index: index, 
                      isPast: isPast, 
                      hasNotification: isCurrentDay && notifiedJourneys.contains(journey.id))
            
            Spacer()
        }
        .id(journey.id)
        .opacity(isPast ? 0.6 : 1.0)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isPast && isCurrentDay {
                NotificationButton(journey: journey,
                                 hasNotification: notifiedJourneys.contains(journey.id),
                                 scheduleViewModel: scheduleViewModel,
                                 isCurrentDay: isCurrentDay,
                                 notifiedJourneys: $notifiedJourneys)
            }
        }
    }
}

private struct TimeColumn: View {
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(formattedTime)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isPast ? .gray : .primary)
            if isCurrentDay, let date = DateTimeUtils.parseTime(formattedTime) {
                let remainingTime = DateTimeUtils.calculateRemainingTime(for: date)
                Text(remainingTime)
                    .font(.caption)
                    .foregroundColor(DateTimeUtils.getTimeColor(remainingTime))
                    .padding(.top, 6)
            }
        }
        .frame(width: 70)
    }
}

private struct InfoColumn: View {
    let journey: Journey
    let index: Int
    let isPast: Bool
    let hasNotification: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Image(systemName: "water.waves")
                    .foregroundColor(isPast ? .gray : .blue)
                Text("\(index + 1). Wave")
                    .foregroundColor(isPast ? .gray : .primary)
                
                Spacer()
                
                if hasNotification {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
            
            HStack(spacing: 8) {
                if let name = journey.name {
                    Text(name.replacingOccurrences(of: "^0+", with: "", options: .regularExpression))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                if let passList = journey.passList,
                   passList.count > 1,
                   let nextStationName = passList[1].station.name {
                    Text("→ \(nextStationName)")
                        .font(.caption)
                        .foregroundColor(isPast ? .gray : .primary)
                }
            }
        }
    }
}

private struct NotificationButton: View {
    let journey: Journey
    let hasNotification: Bool
    let scheduleViewModel: ScheduleViewModel
    let isCurrentDay: Bool
    @Binding var notifiedJourneys: Set<String>
    
    var body: some View {
        Button {
            if hasNotification {
                scheduleViewModel.removeNotification(for: journey)
                notifiedJourneys.remove(journey.id)
            } else if isCurrentDay {
                scheduleViewModel.scheduleNotification(for: journey)
                notifiedJourneys.insert(journey.id)
            }
        } label: {
            Label(hasNotification ? "Remove" : "Notify",
                  systemImage: hasNotification ? "bell.slash" : "bell")
        }
        .tint(hasNotification ? .red : .blue)
        .disabled(!isCurrentDay && !hasNotification)
    }
} 