import Combine
import Foundation

/// OpenFlexure illumination routes are build-specific; v1 keeps layout with an explicit stub.
protocol IlluminationControlling: AnyObject {
    var isHardwareLinked: Bool { get }
    var footnote: String { get }
    var levelPercent: Int { get set }
    var lampOn: Bool { get set }
}

@MainActor
final class StubIlluminationService: ObservableObject, IlluminationControlling {
    var isHardwareLinked: Bool { false }
    var footnote: String {
        "Not linked to hardware in this build. Sliders are UI-only. For real lamp control, inspect /api/v2/docs/swagger-ui on your microscope."
    }
    @Published var levelPercent: Int = 75
    @Published var lampOn: Bool = true
}
