import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var appCtrl: AppController

    @State var roomName: String
    @State var displayName: String

    init() {
        roomName = "test"
        displayName = "iPhone user"
    }

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
    func actionButton(state: AppController.State, isValidForm: Bool) -> some View {
        let disabled = appCtrl.state == .loading || !isValidForm

        Button(
            action: {
                switch state {
                case .awaiting:
                    appCtrl.connect(room: roomName, displayName: displayName)
                case .disconnected:
                    appCtrl.connect(room: roomName, displayName: displayName)
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
            .opacity(disabled ? 0.8 : 1.0)
            .disabled(disabled)
    }

    @ViewBuilder
    func customTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .padding()
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))

            TextField(placeholder, text: text)
                .padding()
                .background(Color.blue.darker(by: 0.6))
                .cornerRadius(6)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.darker(by: 0.6), lineWidth: 2.5)
                )
                .padding(3)
                .foregroundColor(.white)
        }
    }

    var body: some View {
        let isValidForm = !(roomName.isEmpty || displayName.isEmpty)
        let logoPath = Bundle.main.path(forResource: "logo.png", ofType: nil)!

        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 40.0) {
                    Image(uiImage: UIImage(named: logoPath)!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    customTextField(label: "Room name", placeholder: "Room name...", text: $roomName)
                    customTextField(label: "Display name", placeholder: "Display name...", text: $displayName)

                    actionButton(state: appCtrl.state, isValidForm: isValidForm)

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

struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView()
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .previewDisplayName("Default preview")
    }
}
