//
//  TotalActivityView.swift
//  SE7ENDeviceActivityReportExtension
//
//  UI for displaying total screen time
//

import SwiftUI
import DeviceActivity

struct TotalActivityView: View {
    let activityReport: Int // Total minutes
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Total Screen Time")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Text("\(activityReport)")
                    .font(.largeTitle.bold())
                Text("minutes today")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    TotalActivityView(activityReport: 127)
        .padding()
}
