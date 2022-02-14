# MembraneRTC

A package containing a `MembraneRTCEngine` iOS client.

## Functionalities
The package provides all primitives necessary for communicating with the backend service
which should eventually result in receiving WebRTC media streams that can be then played in the target application.

The main class is `MembraneRTC` which is the main client's controller. It is responsible for managing a transport connection
with the server and receiving/sending necessary events necessary for obtaining a valid RTC connection.

To make usage of the client one must implement a `MembraneRTCDelegate` delegate which will notify the listener about:
- new peers joining/leaving the videoroom
- new/old media tracks from present peers
- connection's state and potential connection's errors

### Transport
Besides WebRTC traffic which is based on UDP we need a reliable transport with the backend service that
will relay `MembraneRTCEngine` events.

The package provides `EventTransport` protocol which can be used to implement a custom transport layer with arbitrary backend
implementing the `MembraneRTCEngine`.

By default the package provides a `PhoenixTransport` which is based on `Phoenix Framework` socket and channels mechanism
which is 100% compatible with the Membrane's videoroom example.

### Displaying the video streams
To display the video streams one can use provided classes:
- `VideoView` which is a `UIKit` view
- 'SwiftUIVideoView` which is a SwiftUI wrapper around `VideoView`

