import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            MetalView(model: model)
                .ignoresSafeArea()
            NightOverlay(menu: model.menu)
                .ignoresSafeArea()
            TopBar(model: model, tracker: model.tracker)
            MenuOverlay(menu: model.menu, app: model)
                .ignoresSafeArea()
            PointerOverlay(pointer: model.pointer)
                .ignoresSafeArea()
        }
        .onAppear { model.start() }
    }
}

/// Estado das mãos (canto superior) e miniatura da câmera.
struct TopBar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var tracker: HandTracker

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                Text(tracker.status)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                    .padding(.top, 58)
                    .padding(.leading, 14)
                Spacer()
                if model.showCamera {
                    CameraPreview(session: tracker.session)
                        .frame(width: 104, height: 138)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .padding(.top, 54)
                        .padding(.trailing, 14)
                }
            }
            if model.renderInfo.hasPrefix("ERRO") || model.renderInfo.hasPrefix("GPU") {
                Text(model.renderInfo)
                    .font(.caption2)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
