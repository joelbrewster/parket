import Foundation

@MainActor
package final class Weather {
    package static let shared = Weather()

    package struct Day {
        package let name: String
        package let detail: String
    }

    package private(set) var text = ""
    package private(set) var days: [Day] = []

    private var timer: Timer?
    private var inFlight = false

    private init() {}

    package func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 15 * 60, repeats: true) { _ in
            MainActor.assumeIsolated {
                Weather.shared.refresh()
            }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        guard !inFlight else { return }
        inFlight = true
        Task {
            let next = await WeatherAPI.fetch()
            inFlight = false
            guard let next else { return }
            guard next.text != text || next.days.map(\.detail) != days.map(\.detail) else { return }
            text = next.text
            days = next.days
            Bar.shared.update()
        }
    }
}

private enum WeatherAPI {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    static func fetch() async -> (text: String, days: [Weather.Day])? {
        guard let location = await location() else { return nil }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "5"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { return nil }
        guard let json = await json(from: url) else { return nil }
        guard let current = json["current"] as? [String: Any] else { return nil }
        guard let temperature = number(current["temperature_2m"]) else { return nil }
        let degrees = "\(Int(temperature.rounded()))°"
        let text: String
        if let code = number(current["weather_code"]).map({ Int($0) }) {
            text = "\(label(for: code)) \(degrees)"
        } else {
            text = degrees
        }
        return (text, days(from: json["daily"] as? [String: Any]))
    }

    private static func days(from daily: [String: Any]?) -> [Weather.Day] {
        guard let daily else { return [] }
        guard let times = daily["time"] as? [String] else { return [] }
        let codes = daily["weather_code"] as? [Any] ?? []
        let highs = daily["temperature_2m_max"] as? [Any] ?? []
        let lows = daily["temperature_2m_min"] as? [Any] ?? []
        let parse = DateFormatter()
        parse.calendar = Calendar.current
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.dateFormat = "yyyy-MM-dd"
        let name = DateFormatter()
        name.locale = .current
        name.dateFormat = "EEE"
        return times.enumerated().compactMap { index, value in
            guard let date = parse.date(from: value) else { return nil }
            let day = Calendar.current.isDateInToday(date) ? "Now" : name.string(from: date)
            let code = index < codes.count ? number(codes[index]).map { Int($0) } : nil
            let high = index < highs.count ? number(highs[index]).map { Int($0.rounded()) } : nil
            let low = index < lows.count ? number(lows[index]).map { Int($0.rounded()) } : nil
            let weather = code.map(label(for:)) ?? ""
            let range: String
            if let high, let low {
                range = "\(high)° / \(low)°"
            } else {
                range = ""
            }
            let detail = [weather, range].filter { !$0.isEmpty }.joined(separator: "  ")
            return Weather.Day(name: day, detail: detail)
        }
    }

    private static func location() async -> (latitude: Double, longitude: Double)? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        guard let json = await json(from: url) else { return nil }
        guard json["success"] as? Bool != false else { return nil }
        guard let latitude = number(json["latitude"]), let longitude = number(json["longitude"])
        else { return nil }
        return (latitude, longitude)
    }

    private static func json(from url: URL) async -> [String: Any]? {
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    private static func label(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Cloud"
        case 45, 48: return "Fog"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "Rain"
        case 71, 73, 75, 77, 85, 86: return "Snow"
        case 95, 96, 99: return "Storm"
        default: return "Cloud"
        }
    }
}
