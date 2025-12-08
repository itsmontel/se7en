import SwiftUI
import FamilyControls

/// Displays an app using Apple's Label component with real icon and name from token
struct AppTokenLabel: View {
    let token: AnyHashable
    var style: LabelStyle = .titleAndIcon
    var size: CGFloat = 44
    
    var body: some View {
        if let appToken = token as? ApplicationToken {
            Label(appToken)
                .labelStyle(style)
                .font(.system(size: size * 0.4, weight: .medium))
        } else {
            // Fallback for non-ApplicationToken types
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.4, weight: .medium))
        }
    }
}

/// Horizontal scrollable list of app tokens
struct AppTokenScrollView: View {
    let tokens: [AnyHashable]
    var style: LabelStyle = .titleAndIcon
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(tokens), id: \.self) { token in
                    AppTokenLabel(token: token, style: style)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Grid view of app tokens
struct AppTokenGridView: View {
    let tokens: [AnyHashable]
    let columns: [GridItem]
    var style: LabelStyle = .titleAndIcon
    var onTap: ((AnyHashable) -> Void)? = nil
    
    init(tokens: [AnyHashable], columns: Int = 2, style: LabelStyle = .titleAndIcon, onTap: ((AnyHashable) -> Void)? = nil) {
        self.tokens = tokens
        self.columns = Array(repeating: GridItem(.flexible()), count: columns)
        self.style = style
        self.onTap = onTap
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(tokens), id: \.self) { token in
                Button(action: {
                    onTap?(token)
                }) {
                    VStack(spacing: 12) {
                        AppTokenLabel(token: token, style: style, size: 60)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                }
            }
        }
    }
}

/// Selected apps view using Label tokens
struct SelectedAppsView: View {
    let selection: FamilyActivitySelection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected apps: \(selection.applicationTokens.count)")
                .font(.headline)
            
            if !selection.applicationTokens.isEmpty {
                AppTokenScrollView(tokens: Array(selection.applicationTokens) as [AnyHashable])
            } else {
                Text("No apps selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}



/// Displays an app using Apple's Label component with real icon and name from token
struct AppTokenLabel: View {
    let token: AnyHashable
    var style: LabelStyle = .titleAndIcon
    var size: CGFloat = 44
    
    var body: some View {
        if let appToken = token as? ApplicationToken {
            Label(appToken)
                .labelStyle(style)
                .font(.system(size: size * 0.4, weight: .medium))
        } else {
            // Fallback for non-ApplicationToken types
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.4, weight: .medium))
        }
    }
}

/// Horizontal scrollable list of app tokens
struct AppTokenScrollView: View {
    let tokens: [AnyHashable]
    var style: LabelStyle = .titleAndIcon
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(tokens), id: \.self) { token in
                    AppTokenLabel(token: token, style: style)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Grid view of app tokens
struct AppTokenGridView: View {
    let tokens: [AnyHashable]
    let columns: [GridItem]
    var style: LabelStyle = .titleAndIcon
    var onTap: ((AnyHashable) -> Void)? = nil
    
    init(tokens: [AnyHashable], columns: Int = 2, style: LabelStyle = .titleAndIcon, onTap: ((AnyHashable) -> Void)? = nil) {
        self.tokens = tokens
        self.columns = Array(repeating: GridItem(.flexible()), count: columns)
        self.style = style
        self.onTap = onTap
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(tokens), id: \.self) { token in
                Button(action: {
                    onTap?(token)
                }) {
                    VStack(spacing: 12) {
                        AppTokenLabel(token: token, style: style, size: 60)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                }
            }
        }
    }
}

/// Selected apps view using Label tokens
struct SelectedAppsView: View {
    let selection: FamilyActivitySelection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected apps: \(selection.applicationTokens.count)")
                .font(.headline)
            
            if !selection.applicationTokens.isEmpty {
                AppTokenScrollView(tokens: Array(selection.applicationTokens) as [AnyHashable])
            } else {
                Text("No apps selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

