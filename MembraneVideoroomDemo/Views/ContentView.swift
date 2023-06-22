import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appCtrl: AppController

    var body: some View {
        ZStack {
            Color.blue.darker(by: 0.5).ignoresSafeArea()

            switch appCtrl.state {
            case .connected:
                RoomView(appCtrl.client!, appCtrl.displayName)
            default:
                ConnectView()
            }
        }
        .foregroundColor(Color.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
