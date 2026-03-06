import SwiftUI
import CoreLocation

/// A high-performance zoomable map view that displays a bundled subway map image
/// and overlays the user's current location as a pulsing blue dot.
///
/// Uses UIScrollView for smooth, native-feeling pinch-to-zoom and pan.
struct ZoomableMapView: UIViewRepresentable {
    var userLocation: CLLocation?
    var calibrationMode: Bool = false

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

        let dotSize: CGFloat = 80
        let pulseSize: CGFloat = 200
        let accuracySize: CGFloat = 140

        // Pulse ring
        let pulse = UIView(frame: CGRect(x: (dotSize - pulseSize) / 2, y: (dotSize - pulseSize) / 2,
                                         width: pulseSize, height: pulseSize))
        pulse.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        pulse.layer.cornerRadius = pulseSize / 2
        dotContainer.addSubview(pulse)

        // Accuracy ring
        let accuracyRing = UIView(frame: CGRect(x: (dotSize - accuracySize) / 2, y: (dotSize - accuracySize) / 2,
                                                width: accuracySize, height: accuracySize))
        accuracyRing.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        accuracyRing.layer.cornerRadius = accuracySize / 2
        dotContainer.addSubview(accuracyRing)

        // Core dot
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
        dot.backgroundColor = .systemBlue
        dot.layer.cornerRadius = dotSize / 2
        dot.layer.borderWidth = 6
        dot.layer.borderColor = UIColor.white.cgColor
        dot.layer.shadowColor = UIColor.black.cgColor
        dot.layer.shadowOffset = CGSize(width: 0, height: 2)
        dot.layer.shadowRadius = 6
        dot.layer.shadowOpacity = 0.3
        dotContainer.addSubview(dot)

        dotContainer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotContainer.isHidden = true
        imageView.addSubview(dotContainer)
        imageView.isUserInteractionEnabled = true

        context.coordinator.locationDot = dotContainer
        context.coordinator.pulseDot = pulse

        // Calibration tap gesture
        if calibrationMode {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleCalibrationTap(_:)))
            scrollView.addGestureRecognizer(tap)
        }

        // Load the bundled map image
        if let image = UIImage(named: "subway-map") {
            let size = image.size
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: size)
            context.coordinator.imageSize = size
            scrollView.contentSize = size

            // Defer zoom setup until the scroll view has been laid out by SwiftUI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.configureZoom(for: scrollView, imageSize: size, coordinator: context.coordinator)
            }
        } else {
            context.coordinator.mapMissing = true
        }

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

        // Zoom to user's location the first time it becomes available
        if !coordinator.hasZoomedToLocation,
           coordinator.hasSetInitialZoom,
           let location = userLocation,
           let imageSize = coordinator.imageSize,
           let point = CoordinateMapper.mapToImage(coordinate: location.coordinate, imageSize: imageSize) {
            coordinator.hasZoomedToLocation = true

            // Zoom to ~5× around the user's location
            let zoomScale = scrollView.minimumZoomScale * 5.0
            let visibleWidth = scrollView.bounds.width / zoomScale
            let visibleHeight = scrollView.bounds.height / zoomScale
            let zoomRect = CGRect(
                x: point.x - visibleWidth / 2,
                y: point.y - visibleHeight / 2,
                width: visibleWidth,
                height: visibleHeight
            )

            UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseInOut) {
                scrollView.zoom(to: zoomRect, animated: false)
            }
        }
    }

    // MARK: - Zoom Configuration

    private func configureZoom(for scrollView: UIScrollView, imageSize: CGSize, coordinator: Coordinator) {
        let viewSize = scrollView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else {
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
            print("📍 Location dot → pixel: \(point), imageSize: \(imageSize)")
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
        var hasZoomedToLocation = false
        var isAnimatingPulse = false
        var mapMissing = false

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

        @objc func handleCalibrationTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView = imageView, let imageSize = imageSize else { return }
            let tapInImage = gesture.location(in: imageView)

            let normalizedX = tapInImage.x / imageSize.width
            let normalizedY = tapInImage.y / imageSize.height

            // Log in copy-pasteable format
            print("📌 TAP — normalizedX: \(String(format: "%.3f", normalizedX)), normalizedY: \(String(format: "%.3f", normalizedY))  (pixel: \(Int(tapInImage.x)), \(Int(tapInImage.y)))")

            // Drop a crosshair marker at the tap point
            let marker = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            marker.center = tapInImage
            marker.backgroundColor = UIColor.systemRed.withAlphaComponent(0.5)
            marker.layer.cornerRadius = 15
            marker.layer.borderWidth = 2
            marker.layer.borderColor = UIColor.white.cgColor
            marker.isUserInteractionEnabled = false
            imageView.addSubview(marker)

            // Fade out after 3 seconds
            UIView.animate(withDuration: 1.0, delay: 3.0, options: []) {
                marker.alpha = 0
            } completion: { _ in
                marker.removeFromSuperview()
            }
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
