import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case iris, jade, ocean, rose, amber, graphite, sage, teal, cornflower, lilac
    var id: String { rawValue }
    var name: String {
        switch self {
        case .iris: return "鸢尾紫"
        case .jade: return "松石绿"
        case .ocean: return "远海蓝"
        case .rose: return "蔷薇粉"
        case .amber: return "暖琥珀"
        case .graphite: return "石墨灰"
        case .sage: return "鼠尾草"
        case .teal: return "青竹绿"
        case .cornflower: return "晴空蓝"
        case .lilac: return "雾丁香"
        }
    }
    var hex: String {
        switch self {
        case .iris: return "#5558AA"
        case .jade: return "#287364"
        case .ocean: return "#306BA4"
        case .rose: return "#A34F74"
        case .amber: return "#946324"
        case .graphite: return "#515D6B"
        case .sage: return "#53745E"
        case .teal: return "#367D80"
        case .cornflower: return "#5276A5"
        case .lilac: return "#79709B"
        }
    }
    var color: Color {
        let number = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return Color(red: Double((number >> 16) & 255)/255, green: Double((number >> 8) & 255)/255, blue: Double(number & 255)/255)
    }
    var sidebar: Color { color.opacity(0.075) }
    var editor: Color { color.opacity(0.025) }
}
