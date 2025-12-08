//
//  TotalActivityView.swift
//  SE7ENDeviceActivityReportExtension
//
//  Created by Montel Nevers on 05/12/2025.
//

import SwiftUI

struct TotalActivityView: View {
    let totalActivity: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
            
        Text(totalActivity)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
}

// In order to support previews for your extension's custom views, make sure its source files are
// members of your app's Xcode target as well as members of your extension's target. You can use
// Xcode's File Inspector to modify a file's Target Membership.
#Preview {
    TotalActivityView(totalActivity: "1h 23m")
}
