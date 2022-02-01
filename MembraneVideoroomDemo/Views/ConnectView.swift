import SwiftUI
import AVFoundation

struct ConnectView: View {
    @EnvironmentObject var appCtrl: AppController
    
    func actionButtonLabel(state: AppController.State) -> String {
        switch state {
        case .awaiting:
            return "Join the room"
        case .disconnected:
            return "Rejoin the room"
        case .error:
            return "Try again"
        case .connected:
            return "You should not be here..."
        case .loading:
            return "Loading..."
        }
    }
    
    @ViewBuilder
    func actionButton(state: AppController.State) -> some View {
        Button(
            action: {
                switch state {
                case .awaiting:
                    appCtrl.connect()
                case .disconnected:
                    appCtrl.connect()
                case .error:
                    appCtrl.reset()
                default:
                    break
                }
            },
            label: {
                Text(actionButtonLabel(state: appCtrl.state))
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        ).background(Color.blue.darker())
            .cornerRadius(8)
            .disabled(appCtrl.state == .loading)
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 40.0) {
                    
                    Button(
                        action: {
                            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { _ in })
                        },
                        label: {
                            HStack {
                                Text("Allow")
                                    .fontWeight(.bold)
                                    .padding(.leading, 12)
                                    .padding(.vertical, 10)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.white)
                                    .padding(.trailing, 12)
                            }
                        }
                    ).background(Color.blue.darker())
                        .cornerRadius(8)
                    
                    actionButton(state: appCtrl.state)
                    if appCtrl.state == .error {
                        Text("Encountered an error")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
    }
}
