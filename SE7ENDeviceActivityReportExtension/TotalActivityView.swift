//
//  TotalActivityView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI

struct TotalActivityView: View {
    let totalActivity: TotalActivityData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(format(duration: totalActivity.totalDuration))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("\(totalActivity.appsCount) apps")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Helper function to format duration
    private func format(duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}









