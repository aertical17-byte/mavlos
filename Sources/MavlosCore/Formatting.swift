import Foundation

/// Formattazione numerica e percorsi per l'interfaccia (locale italiana).
public enum Formatting {
    private static let itLocale = Locale(identifier: "it_IT")

    private static var sizeFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = itLocale
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }

    /// Conteggio con separatore di migliaia all'italiana: 1248 -> "1.248".
    public static func fileCount(_ value: Int) -> String {
        let f = NumberFormatter()
        f.locale = itLocale
        f.groupingSeparator = "."
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Dimensione leggibile: "2,4 GB", "640 MB", "18 KB".
    public static func fileSize(_ bytes: Int64) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0

        let formatter = sizeFormatter
        func render(_ value: Double, unit: String, fractionDigits: Int) -> String {
            formatter.maximumFractionDigits = fractionDigits
            formatter.minimumFractionDigits = 0
            return (formatter.string(from: NSNumber(value: value)) ?? "0") + " " + unit
        }

        let doubleBytes = Double(max(0, bytes))
        switch doubleBytes {
        case ..<kb:
            return "1 KB"
        case ..<mb:
            return render(doubleBytes / kb, unit: "KB", fractionDigits: 0)
        case ..<gb:
            return render(doubleBytes / mb, unit: "MB", fractionDigits: 0)
        default:
            return render(doubleBytes / gb, unit: "GB", fractionDigits: 1)
        }
    }

    /// "2.412 di 3.108"
    public static func progress(_ done: Int, _ total: Int) -> String {
        "\(fileCount(done)) di \(fileCount(total))"
    }
}
