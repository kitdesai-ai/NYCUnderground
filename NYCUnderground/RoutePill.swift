import SwiftUI

/// A colored circle with a subway line letter, matching official MTA colors.
struct RoutePill: View {
    let route: String
    var size: CGFloat = 22

    var body: some View {
        Text(route)
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundColor(textColor)
            .frame(width: size, height: size)
            .background(routeColor)
            .clipShape(Circle())
    }

    private var routeColor: Color {
        Self.colors[route] ?? .gray
    }

    private var textColor: Color {
        // Yellow lines need dark text
        if ["N", "Q", "R", "W"].contains(route) {
            return .black
        }
        return .white
    }

    static let colors: [String: Color] = [
        "1": Color(red: 0.93, green: 0.24, blue: 0.27),
        "2": Color(red: 0.93, green: 0.24, blue: 0.27),
        "3": Color(red: 0.93, green: 0.24, blue: 0.27),
        "4": Color(red: 0.0, green: 0.58, blue: 0.25),
        "5": Color(red: 0.0, green: 0.58, blue: 0.25),
        "6": Color(red: 0.0, green: 0.58, blue: 0.25),
        "7": Color(red: 0.72, green: 0.21, blue: 0.67),
        "A": Color(red: 0.0, green: 0.24, blue: 0.64),
        "C": Color(red: 0.0, green: 0.24, blue: 0.64),
        "E": Color(red: 0.0, green: 0.24, blue: 0.64),
        "B": Color(red: 1.0, green: 0.39, blue: 0.0),
        "D": Color(red: 1.0, green: 0.39, blue: 0.0),
        "F": Color(red: 1.0, green: 0.39, blue: 0.0),
        "M": Color(red: 1.0, green: 0.39, blue: 0.0),
        "G": Color(red: 0.42, green: 0.75, blue: 0.26),
        "J": Color(red: 0.6, green: 0.4, blue: 0.22),
        "Z": Color(red: 0.6, green: 0.4, blue: 0.22),
        "L": Color(red: 0.6, green: 0.6, blue: 0.6),
        "N": Color(red: 0.99, green: 0.81, blue: 0.1),
        "Q": Color(red: 0.99, green: 0.81, blue: 0.1),
        "R": Color(red: 0.99, green: 0.81, blue: 0.1),
        "W": Color(red: 0.99, green: 0.81, blue: 0.1),
        "S": Color(red: 0.5, green: 0.5, blue: 0.5),
        "GS": Color(red: 0.5, green: 0.5, blue: 0.5),
        "FS": Color(red: 0.5, green: 0.5, blue: 0.5),
        "H": Color(red: 0.5, green: 0.5, blue: 0.5),
        "SI": Color(red: 0.0, green: 0.24, blue: 0.64),
    ]
}
