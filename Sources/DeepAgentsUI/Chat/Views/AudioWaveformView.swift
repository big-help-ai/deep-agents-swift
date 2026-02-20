import SwiftUI

/// Animated audio waveform visualization that responds to an audio level value.
/// Uses TimelineView for true per-frame animation with smooth level interpolation.
struct AudioWaveformView: View {
    /// Normalized audio level (0.0–1.0).
    let level: Float
    let barCount: Int
    let color: Color
    let width: CGFloat
    let maxHeight: CGFloat

    /// Smoothed level that interpolates toward the target each frame.
    @State private var smoothedLevel: CGFloat = 0

    init(
        level: Float,
        barCount: Int = 5,
        color: Color = .green,
        width: CGFloat = 120,
        maxHeight: CGFloat = 80
    ) {
        self.level = level
        self.barCount = barCount
        self.color = color
        self.width = width
        self.maxHeight = maxHeight
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(color)
                        .frame(width: barWidth, height: barHeight(for: index, time: time))
                }
            }
            .frame(width: width, height: maxHeight)
        }
        .onChange(of: level) { _, newValue in
            // Animate the smoothed level toward the new target
            withAnimation(.easeOut(duration: 0.12)) {
                smoothedLevel = CGFloat(min(max(newValue, 0), 1))
            }
        }
    }

    // MARK: - Layout

    private var barWidth: CGFloat {
        let totalSpacing = barSpacing * CGFloat(barCount - 1)
        return (width - totalSpacing) / CGFloat(barCount)
    }

    private var barSpacing: CGFloat { 6 }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let minHeight: CGFloat = 8

        // Each bar oscillates at a slightly different frequency and phase
        let baseFreq = 2.5
        let freqVariation = 1.0 + Double(index) * 0.3
        let phaseOffset = Double(index) * .pi * 2 / Double(barCount)
        let sine = (sin(time * baseFreq * freqVariation + phaseOffset) + 1) / 2 // 0..1

        // Idle shimmer when silent, full amplitude when speaking
        let idleAmplitude: CGFloat = 0.12
        let amplitude = idleAmplitude + (1 - idleAmplitude) * smoothedLevel
        let height = minHeight + (maxHeight - minHeight) * amplitude * sine

        return max(height, minHeight)
    }
}

#Preview {
    VStack(spacing: 40) {
        AudioWaveformView(level: 0)
        AudioWaveformView(level: 0.3)
        AudioWaveformView(level: 0.7)
        AudioWaveformView(level: 1.0)
    }
    .padding()
    .background(Color.black)
}
