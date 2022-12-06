## Components
The repository consists of 3 separapable components:
- `MembraneRTC` -  Membrane WebRTC client fully compatible with `Membrane RTC Engine`, responsible for exchaning media events and receiving media streams which then are presented to the user
- `MembraneVideoroomDemo` - Demo application utilizing `MembraneRTC` client
- `ScreenBroadcastExt` - An instance of `Broadcast Upload Extension` providing a screencast funcionality to the Demo application

### MembraneRTC
The main goal of the client was to be as similar to [web version](https://github.com/membraneframework/membrane_rtc_engine) as possible.
Just like with web client, the native mobile client is pretty raw. It is as low level as possible without exposing any of WebRTC details.
It is user's responsibility to keep track of all peers in the room and their corresponding tracks. The client's responsibility is just to 
notify the user about all the changes regarding the underlying session with the backend server.

What user needs to do is just to provide config necessary for client connection, create local tracks (audio, video or screencast) 
start the client and listen for any changes via `MembraneRTCDelegate` protocol.

### MembraneVideoroomDemo
Really simple App allowing to test all `Membrane RTC Engine` functionalities. It consist of 2 screens:
- Joining screen where user passes room's name and his/her display name followed by join button click
- Room's screen consisting of set of control buttons and an area where participants' videos get displayed

The user has the following control buttons at hand:
- microphone mute/unmute toggle
- camera video mute/unmute toggle
- leave call button
- front/back camera switch
- screencast button for displaying a list of `Broadcast Upload Extensions` where `ScreencastBroadcastExt` can be used for recording the whole device's screen

Additionaly a user can tap on any of visible video tiles to focus them as a primary video


### ScreenBroadcastExt
Sharing the whole device's screen even if application goes into a background mode in iOS is not trivial.
For it to happen we must use an extension called `Broadcast Upload Extension`. It is reponsible for capturing 
video buffers of the screen being recorded and performing arbitrary work to send it somewhere else.

In our case we need to start an instance of the upload extension and provide the created video buffers back to the application.
Unfortunately an extension gets started as a separate process which enforces us to use some Inter Process Communication mechanisms.
In our case we are using `CFMessagePort` which is Core Foundation mechanism for transmitting arbitrary data between threads/processes on local machine.

To conduct the buffers exchange we need to run 2 instances of such a port:
- local (server mode)
- remote (client mode)

One process (server) needs to create a port that it will be listening on. The other process (client) needs
to create a remtoe port for writing purposes that will point to the server one. Once that connection is created
the client needs to serialize the buffers using `Proto Buffers` mechanism (code available at `MembraneRTC/Sources/MembraneRTC/IPC`).
The server then can capture and deserialize the packets which will get forwarded to the `Membrane RTC Engine` resulting in full screen sharing experience.

*IMPORTANT*
Both extensnion and application must share the same App Group so that a proper CFMessagePort can get created.

## Documentation
API documentation is available [here](https://docs.membrane.stream/membrane-webrtc-ios/documentation/membranertc/).

## Necessary setup
For the application to work properly one must set necessary constants inside 
`MembraneVideoroomDemo/Utilities/Constants.swift`. 

One important variable is the remote server address `rtcEngineUrl` that the users will connect to.

Two of variables are related with screenast functionality:
- `appGroup` - app group identifier that must be shared with the application and broadcast extension 
- `screencastExtensionBundleId` - bundle identier of the `ScreenBroadcastExt`


*NOTE* `appGroup` used in `Constants.swift` must be replicated inside `ScreenBroadcastExt/SampleHandler.swift` file.

## Installation

### Cocoapods
Add in your app's Podfile:
```
pod 'MembraneRTC'
```

In your ScreenBroadcast extension target:
```
target 'ScreenBroadcast' do
  pod 'MembraneRTC/Broadcast'
end
```

## Developing
1. Run `./scripts/init.sh` in the main directory to install swift-format and release-it and set up git hooks
2. Edit `Debug.xcconfig` to set backend url in development.
2. Run `release-it` to release. Follow the prompts, it should update version in podspec, make a commit and tag and push the new version to Cocoa Pods.

## Credits
This project is highly inspired by the [LiveKit](https://livekit.io/) project and their implementation of the [iOS SDK](https://github.com/livekit/client-sdk-swift) and reuses a lot of their implemented solutions (mainly dealing with WebRTC SDK while the signalling got completely replaced with an internal solution).

This project has been built and is maintained thanks to the support from [dscout](https://dscout.com/) and [Software Mansion](https://swmansion.com).

<img alt="dscout" height="100" src="./.github/dscout_logo.png"/>
<img alt="Software Mansion" src="https://logo.swmansion.com/logo?color=white&variant=desktop&width=150&tag=react-native-reanimated-github"/>
