//
//  ActionFeedbackBanner.swift
//  clippystack
//

import SwiftUI

struct ActionFeedbackBanner: View {
    let status: FooterStatus

    private var accentColor: Color {
        switch status.kind {
        case .success:
            return Color(red: 0.50, green: 0.89, blue: 0.58)
        case .warning:
            return Color(red: 1.0, green: 0.88, blue: 0.45)
        case .error:
            return Color(red: 1.0, green: 0.55, blue: 0.50)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)

            Text(status.message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
        }
    }
}
