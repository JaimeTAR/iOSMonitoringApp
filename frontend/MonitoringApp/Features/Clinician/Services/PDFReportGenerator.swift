import UIKit

/// Generates a PDF document from patient report data using Core Graphics
struct PDFReportGenerator {

    /// Generates PDF data from the given report. Returns nil on failure.
    static func generatePDF(from report: PatientReportData) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.label
            ]
            let title = "Patient Report"
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
            yOffset += titleSize.height + 16

            // Patient name
            yOffset = drawField("Patient", value: report.patientName, at: yOffset, margin: margin, width: contentWidth)

            // Report period
            yOffset = drawField("Period", value: report.reportPeriod, at: yOffset, margin: margin, width: contentWidth)

            // Generated date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            yOffset = drawField("Generated", value: dateFormatter.string(from: report.generatedDate), at: yOffset, margin: margin, width: contentWidth)

            yOffset += 12

            // Separator
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: margin, y: yOffset))
            separatorPath.addLine(to: CGPoint(x: margin + contentWidth, y: yOffset))
            UIColor.separator.setStroke()
            separatorPath.lineWidth = 0.5
            separatorPath.stroke()
            yOffset += 16

            // Metrics
            if let hr = report.avgHeartRate {
                yOffset = drawField("Average Heart Rate", value: String(format: "%.0f BPM", hr), at: yOffset, margin: margin, width: contentWidth)
            }
            if let rmssd = report.avgRMSSD {
                yOffset = drawField("Average RMSSD", value: String(format: "%.0f ms", rmssd), at: yOffset, margin: margin, width: contentWidth)
            }
            if let sdnn = report.avgSDNN {
                yOffset = drawField("Average SDNN", value: String(format: "%.0f ms", sdnn), at: yOffset, margin: margin, width: contentWidth)
            }
            yOffset = drawField("Session Count", value: "\(report.sessionCount)", at: yOffset, margin: margin, width: contentWidth)
            yOffset = drawField("Total Monitoring Time", value: formatMinutes(report.totalMonitoringMinutes), at: yOffset, margin: margin, width: contentWidth)
        }

        return data
    }

    // MARK: - Private Helpers

    private static func drawField(_ label: String, value: String, at y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ]

        var yOffset = y
        label.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: labelAttrs)
        yOffset += 16
        value.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: valueAttrs)
        yOffset += 22
        return yOffset
    }

    private static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
