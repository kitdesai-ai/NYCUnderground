import SwiftUI
import CoreLocation

/// A high-performance zoomable map view that renders a bundled PDF at high resolution
/// and overlays the user's current location as a pulsing blue dot.
///
/// Uses UIScrollView for smooth, native-feeling pinch-to-zoom and pan.
/// The PDF is rendered once to a bitmap at `renderScale`× resolution.
struct ZoomableMapView: UIViewRepresentable {
    var userLocation: CLLocation?

    /// Must match CoordinateMapper.renderScale
    private let renderScale: CGFloat = 4.0

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .systemBackground
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.decelerationRate = .normal

        // Content: the rendered map image
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Location dot (added as subview of imageView so it scrolls/zooms with map)
        let dotContainer = UIView()
        dotContainer.isUserInteractionEnabled = false

        // Pulse ring
        let pulse = UIView(frame: CGRect(x: -16, y: -16, width: 48, height: 48))
        pulse.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        pulse.layer.cornerRadius = 24
        dotContainer.addSubview(pulse)

        // Accuracy ring
        let accuracyRing = UIView(frame: CGRect(x: -8, y: -8, width: 32, height: 32))
        accuracyRing.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        accuracyRing.layer.cornerRadius = 16
        dotContainer.addSubview(accuracyRing)

        // Core dot
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        dot.backgroundColor = .systemBlue
        dot.layer.cornerRadius = 8
        dot.layer.borderWidth = 2.5
        dot.layer.borderColor = UIColor.white.cgColor
        dot.layer.shadowColor = UIColor.black.cgColor
        dot.layer.shadowOffset = CGSize(width: 0, height: 1)
        dot.layer.shadowRadius = 3
        dot.layer.shadowOpacity = 0.3
        dotContainer.addSubview(dot)

        dotContainer.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        dotContainer.isHidden = true
        imageView.addSubview(dotContainer)
        imageView.isUserInteractionEnabled = true

        context.coordinator.locationDot = dotContainer
        context.coordinator.pulseDot = pulse

        // Render the PDF
        renderPDF(into: imageView, coordinator: context.coordinator)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator

        // Set initial zoom to fit on first layout pass
        if !coordinator.hasSetInitialZoom, let imageSize = coordinator.imageSize {
            let viewSize = scrollView.bounds.size
            guard viewSize.width > 0, viewSize.height > 0 else { return }

            let widthScale = viewSize.width / imageSize.width
            let heightScale = viewSize.height / imageSize.height
            let fitScale = min(widthScale, heightScale)

            scrollView.minimumZoomScale = fitScale
            scrollView.maximumZoomScale = max(fitScale * 12, 1.0)
            scrollView.zoomScale = fitScale

            coordinator.hasSetInitialZoom = true
            centerContent(in: scrollView, coordinator: coordinator)
        }

        // Update location dot position
        updateLocationDot(coordinator: coordinator)
    }

    // MARK: - PDF Rendering

    private func renderPDF(into imageView: UIImageView, coordinator: Coordinator) {
        print("🚀 renderPDF called")
        guard let url = Bundle.main.url(forResource: "subway-map", withExtension: "pdf") else {
            print("❌ PDF URL not found")
            coordinator.pdfMissing = true
            return
        }
        print("✅ PDF URL: \(url)")

        guard let document = CGPDFDocument(url as CFURL) else {
            print("❌ CGPDFDocument failed to open")
            coordinator.pdfMissing = true
            return
        }
        print("✅ PDF document pages: \(document.numberOfPages)")

        guard let page = document.page(at: 1) else {
            print("❌ Could not get page 1")
            coordinator.pdfMissing = true
            return
        }
        print("✅ Got PDF page 1")

        let pageRect = page.getBoxRect(.mediaBox)
        let imageWidth = pageRect.width * renderScale
        let imageHeight = pageRect.height * renderScale
        let size = CGSize(width: imageWidth, height: imageHeight)
        print("📐 PDF page rect: \(pageRect)")
        print("📐 Render size: \(size)")

        // Render on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { ctx in
                let cgContext = ctx.cgContext
                // White background
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
                // PDF renders with origin at bottom-left; flip for UIKit
                cgContext.translateBy(x: 0, y: size.height)
                cgContext.scaleBy(x: renderScale, y: -renderScale)
                cgContext.drawPDFPage(page)
            }

            DispatchQueue.main.async {
                print("🖼️ Image rendered: \(image.size), scale: \(image.scale)")
                imageView.image = image
                imageView.frame = CGRect(origin: .zero, size: size)
                coordinator.imageSize = size

                if let scrollView = imageView.superview as? UIScrollView {
                    print("📦 ScrollView bounds: \(scrollView.bounds)")
                    scrollView.contentSize = size
                    coordinator.hasSetInitialZoom = false

                    // Defer zoom setup to ensure SwiftUI has laid out the scroll view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.configureZoom(for: scrollView, imageSize: size, coordinator: coordinator)
                    }
                }
            }
        }
    }

    // MARK: - Zoom Configuration

    private func configureZoom(for scrollView: UIScrollView, imageSize: CGSize, coordinator: Coordinator) {
        let viewSize = scrollView.bounds.size
        print("🔍 configureZoom — viewSize: \(viewSize), imageSize: \(imageSize)")
        guard viewSize.width > 0, viewSize.height > 0 else {
            // Still not laid out — try again shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.configureZoom(for: scrollView, imageSize: imageSize, coordinator: coordinator)
            }
            return
        }

        let fitScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        scrollView.minimumZoomScale = fitScale
        scrollView.maximumZoomScale = max(fitScale * 12, 1.0)
        scrollView.zoomScale = fitScale
        coordinator.hasSetInitialZoom = true
        centerContent(in: scrollView, coordinator: coordinator)
    }

    // MARK: - Location Dot

    private func updateLocationDot(coordinator: Coordinator) {
        guard let location = userLocation,
              let imageSize = coordinator.imageSize,
              let dot = coordinator.locationDot else {
            coordinator.locationDot?.isHidden = true
            return
        }

        if let point = CoordinateMapper.mapToImage(
            coordinate: location.coordinate,
            imageSize: imageSize
        ) {
            dot.center = point
            dot.isHidden = false

            if !coordinator.isAnimatingPulse {
                coordinator.startPulseAnimation()
            }
        } else {
            dot.isHidden = true
        }
    }

    // MARK: - Content Centering

    private func centerContent(in scrollView: UIScrollView, coordinator: Coordinator) {
        guard let imageView = coordinator.imageView else { return }
        let boundsSize = scrollView.bounds.size
        let contentSize = imageView.frame.size

        let xOffset = max(0, (boundsSize.width - contentSize.width) / 2)
        let yOffset = max(0, (boundsSize.height - contentSize.height) / 2)

        imageView.frame.origin = CGPoint(x: xOffset, y: yOffset)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        var locationDot: UIView?
        var pulseDot: UIView?
        var imageSize: CGSize?
        var hasSetInitialZoom = false
        var isAnimatingPulse = false
        var pdfMissing = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            let contentSize = imageView.frame.size

            let xOffset = max(0, (boundsSize.width - contentSize.width) / 2)
            let yOffset = max(0, (boundsSize.height - contentSize.height) / 2)

            imageView.frame.origin = CGPoint(x: xOffset, y: yOffset)
        }

        func startPulseAnimation() {
            guard let pulse = pulseDot else { return }
            isAnimatingPulse = true

            pulse.transform = .identity
            pulse.alpha = 1.0

            UIView.animate(
                withDuration: 2.0,
                delay: 0,
                options: [.repeat, .curveEaseOut]
            ) {
                pulse.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
                pulse.alpha = 0.0
            }
        }
    }
}
