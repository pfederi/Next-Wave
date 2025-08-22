import SwiftUI

struct ScheduleFooterView: View {
    let stationName: String
    @StateObject private var scheduleService = SchedulePeriodService()
    
    var body: some View {
        if let message = scheduleService.getCountdownMessageForStation(stationName) {
            VStack(spacing: 0) {
                Divider()
                
                HStack(alignment: .center) {
                    Spacer()
                    
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.callout)
                    
                    Text(message)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color("background-color"))
            }
        }
    }
}
