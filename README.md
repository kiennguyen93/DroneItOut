# Drone It Out

## What is this?
Autopilot App for DJI Phantom 3

DroneItOut is an app that enables you to perform different tasks with your DJI Product autonomously. You can control the drone through three main modes, Waypoints Mission, Follow Me, and Voice Commands. Beside those modes, the user also has the ability to control many other subsystems of the product including the camera and gimbal. Using the DroneItOut app, you will discover the full potential of DJI products.

## Get Started Immediately

### SDK Installation with CocoaPods

Since this project has been integrated with [DJI iOS SDK CocoaPods](https://cocoapods.org/pods/DJI-SDK-iOS) now, please check the following steps to install **DJISDK.framework** using CocoaPods after you downloading this project:

**1.** Install CocoaPods

Open Terminal and change to the download project's directory, enter the following command to install it:

~~~
sudo gem install cocoapods
~~~

The process may take a long time, please wait. For further installation instructions, please check [this guide](https://guides.cocoapods.org/using/getting-started.html#getting-started).

**2.** Install SDK with CocoaPods in the Project

Run the following command in the **ObjcSampleCode** and **SwiftSampleCode** paths:

~~~
pod install
~~~

If you install it successfully, you should get the messages similar to the following:

~~~
Analyzing dependencies
Downloading dependencies
Installing DJI-SDK-iOS (4.3.2)
Generating Pods project
Integrating client project

[!] Please close any current Xcode sessions and use `DJISdkDemo.xcworkspace` for this project from now on.
Pod installation complete! There is 1 dependency from the Podfile and 1 total pod
installed.
~~~

> **Note**: If you saw "Unable to satisfy the following requirements" issue during pod install, please run the following commands to update your pod repo and install the pod again:
> 
> ~~~
> pod repo update
> pod install
> ~~~
### Run the App
The app needs to be built and ran through XCode first.

Next, The user can connect their iPhone or iPad to Xcode and have the application installed to their device.

Before running the app, the user needs to turn the aircraft and the controller on. The user needs to wait for the green light on the controller, which indicates a successful connection between the drone and the controller. After the the drone has been warmed up, the user can connect to the drone's wireless network.

On the mobile device, the user needs to connect  to the drone's wireless network. The name of the network usually starts with ***"Phantom3....."*** . The default password for the network is ***12341234***.

Last but not least, make sure that the camera and the memory card are attached to the aircraft. Those component are required for capturing pictures and videos.

Once the aircraft is connected to the application, a red symbol should appear on the map. At this point, the drone is ready for DroneItOut!

## Learn More about DJI Products and the Mobile SDK

Please visit [DJI Mobile SDK Documentation](https://developer.dji.com/mobile-sdk/documentation/introduction/index.html) for more details.

## SDK API Reference

[**iOS SDK API Documentation**](http://developer.dji.com/api-reference/ios-api/index.html)
## Support

You can get support from DJI with the following methods:

- [**DJI Forum**](http://forum.dev.dji.com/en)
- Post questions in [**Stackoverflow**](http://stackoverflow.com) using [**dji-sdk**](http://stackoverflow.com/questions/tagged/dji-sdk) tag
- dev@dji.com
