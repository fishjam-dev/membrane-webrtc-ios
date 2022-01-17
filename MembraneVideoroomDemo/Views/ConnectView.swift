import SwiftUI

struct ConnectView: View {
  @EnvironmentObject var appCtrl: AppController

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .center, spacing: 40.0) {
          Button(
            action: {
                appCtrl.connect()
            },
            label: {
              Text("Join the room")
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
          ).background(Color.blue.darker())
            .cornerRadius(8)
        }
        .padding()
        .frame(width: geometry.size.width)
        .frame(minHeight: geometry.size.height)
      }
    }
  }
}
