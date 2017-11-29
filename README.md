#Drone It Out

##What is this?
Autopilot App for DJI Phantom 3

DroneItOut is an app that enables you to automate your DJI Product. You can control flight throught three main modes, waypoints mission, follow me, and voice control and many subsystems of the product including the camera and gimbal. Using the DroneItOut app, you will discover the full potential of DJI products.

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
Before you run the app, you need to power on the aircraft and remote controller. On your device, you need to connect DJI wireless network. You should wait in 20s for the reomote controller to connect with the aircraft. The green line on remote controller indicates that it's connected sucessfully. You will see the name of the wifi network like ***"Phantom3.."*** on you wireless list setting. 
To connect that wifi network, you can use the default password ***"12341234"***
One more thing, make sure that the camera and the memory card are attached to the aircraft. Those component will be required to the applicaiton. 

## Learn More about DJI Products and the Mobile SDK

Please visit [DJI Mobile SDK Documentation](https://developer.dji.com/mobile-sdk/documentation/introduction/index.html) for more details.

## SDK API Reference

[**iOS SDK API Documentation**](http://developer.dji.com/api-reference/ios-api/index.html)
## Support

You can get support from DJI with the following methods:

- [**DJI Forum**](http://forum.dev.dji.com/en)
- Post questions in [**Stackoverflow**](http://stackoverflow.com) using [**dji-sdk**](http://stackoverflow.com/questions/tagged/dji-sdk) tag
- dev@dji.com
