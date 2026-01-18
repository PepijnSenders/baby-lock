import SwiftUI

/// Represents a single floating letter with animation state
struct FloatingLetter: Identifiable {
    let id = UUID()
    let character: String
    let position: CGPoint
    let color: Color
    let rotation: Double
    let scale: CGFloat
}

/// Observable model for managing floating letters
class KeystrokeOverlayModel: ObservableObject {
    @Published var letters: [FloatingLetter] = []

    /// Bright, fun colors for baby-friendly display
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        Color(red: 1, green: 0.4, blue: 0.7),   // Hot pink
        Color(red: 0, green: 0.8, blue: 0.8),   // Cyan
        Color(red: 1, green: 0.6, blue: 0),     // Bright orange
    ]

    /// Adds a new floating letter at a random position
    func addLetter(_ character: String, screenSize: CGSize) {
        // Random position with padding from edges
        let padding: CGFloat = 100
        let x = CGFloat.random(in: padding...(screenSize.width - padding))
        let y = CGFloat.random(in: padding...(screenSize.height - padding))

        let letter = FloatingLetter(
            character: character,
            position: CGPoint(x: x, y: y),
            color: colors.randomElement() ?? .white,
            rotation: Double.random(in: -30...30),
            scale: CGFloat.random(in: 0.8...1.2)
        )

        letters.append(letter)

        // Remove letter after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.letters.removeAll { $0.id == letter.id }
        }

        // Limit max letters on screen to prevent memory issues
        if letters.count > 20 {
            letters.removeFirst()
        }
    }
}

/// View for a single animated floating letter
struct FloatingLetterView: View {
    let letter: FloatingLetter
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 0
    @State private var currentScale: CGFloat = 0.5

    var body: some View {
        Text(letter.character)
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .foregroundColor(letter.color)
            .shadow(color: letter.color.opacity(0.8), radius: 10)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
            .rotationEffect(.degrees(letter.rotation))
            .scaleEffect(currentScale * letter.scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .position(letter.position)
            .onAppear {
                // Animate in: scale up and fade in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    opacity = 1
                    currentScale = 1
                }
                // Float upward
                withAnimation(.easeOut(duration: 1.5)) {
                    yOffset = -50
                }
                // Fade out
                withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
                    opacity = 0
                }
            }
    }
}

/// Overlay view showing all floating letters
struct KeystrokeOverlayView: View {
    @ObservedObject var model: KeystrokeOverlayModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(model.letters) { letter in
                    FloatingLetterView(letter: letter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}
