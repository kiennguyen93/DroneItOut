//
//  DJIBaseViewController.swift
//  DroneItOut
//
//  Created by Daniel Nguyen on 9/16/17.
//  Copyright © 2017 DJI. All rights reserved.
//

import UIKit
import DJISDK

protocol DJIProductObjectProtocol {
    func fetchAircraft() -> DJIAircraft?
    func fetchCamera() -> DJICamera?
    func fetchGimbal() -> DJIGimbal?
    func fetchFlightController() -> DJIFlightController?
    func fetchRemoteController() -> DJIRemoteController?
    func fetchBattery() -> DJIBattery?
    func fetchAirLink() -> DJIAirLink?
    func fetchHandheldController() -> DJIHandheldController?
}

class ConnectedProductManager: DJIProductObjectProtocol {
    static let sharedInstance = ConnectedProductManager()
    
    var connectedProduct:DJIBaseProduct? = nil
    var product = DJISDKManager.product()
    
    //return product
    func fetchAircraft() -> DJIAircraft? {
        if (product == nil) {
            return nil
        }
        if (product is DJIAircraft) {
            return (product as! DJIAircraft)
        }
        return nil
    }
    
    //return camera component
    func fetchCamera() -> DJICamera? {
        if (self.connectedProduct == nil) {
            return nil
        }
        if (self.connectedProduct is DJIAircraft) {
            return (self.connectedProduct as! DJIAircraft).camera
        }
        else if (self.connectedProduct is DJIHandheld) {
            return (self.connectedProduct as! DJIHandheld).camera
        }
        
        return nil
    }
    //return Gimbal from product
    func fetchGimbal() -> DJIGimbal? {
        if (self.connectedProduct == nil) {
            return nil
        }
        if (self.connectedProduct is DJIAircraft) {
            return (self.connectedProduct as! DJIAircraft).gimbal
        }
        else if (self.connectedProduct is DJIHandheld) {
            return (self.connectedProduct as! DJIHandheld).gimbal
        }
        return nil
    }
    //return flight controller from product
    func fetchFlightController() -> DJIFlightController? {
        
        if (product == nil) {
            return nil
        }
        if product!.isKind(of: DJIAircraft.self){
            return (product as! DJIAircraft).flightController
        }
        return nil
    }
    //return remote controller from product
    func fetchRemoteController() -> DJIRemoteController? {
        if (self.connectedProduct == nil) {
            return nil
        }
        if (self.connectedProduct is DJIAircraft) {
            return (self.connectedProduct as! DJIAircraft).remoteController
        }
        return nil
    }
    //this function will return battery property, you can use it to check battery status
    func fetchBattery() -> DJIBattery? {
        if (self.connectedProduct == nil) {
            return nil
        }
        if (self.connectedProduct is DJIAircraft) {
            return (self.connectedProduct as! DJIAircraft).battery
        }
        else if (self.connectedProduct is DJIHandheld) {
            return (self.connectedProduct as! DJIHandheld).battery
        }
        
        return nil
    }
    //return airlink property
    func fetchAirLink() -> DJIAirLink? {
        if (product == nil) {
            return nil
        }
        if (product is DJIAircraft) {
            return (product as! DJIAircraft).airLink
        }
        else if (product is DJIHandheld) {
            return (product as! DJIHandheld).airLink
        }
        
        return nil
    }
    func fetchHandheldController() -> DJIHandheldController? {
        if (product == nil) {
            return nil
        }
        if (product is DJIHandheld) {
            return (product as! DJIHandheld).handheldController
        }
        return nil
    }
    //set delegation to product
    func setDelegate(delegate:DJIBaseProductDelegate?) {
        product?.delegate = delegate
    }
    
}
//we use this class to connect the aircraft
class DJIBaseViewController: UIViewController, DJIBaseProductDelegate, DJIProductObjectProtocol {
    
    var connectedProduct:DJIBaseProduct?=nil
    var moduleTitle:String?=nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if (moduleTitle != nil) {
            self.title = moduleTitle
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (ConnectedProductManager.sharedInstance.product != nil) {
            ConnectedProductManager.sharedInstance.setDelegate(delegate: self)
        }
    }
    override func viewWillDisappear(
        _ animated: Bool) {
        super.viewWillDisappear(animated)
        if (ConnectedProductManager.sharedInstance.product != nil &&
            ConnectedProductManager.sharedInstance.product?.delegate === self) {
            ConnectedProductManager.sharedInstance.setDelegate(delegate: nil)
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    //call product manager to set delegate
    func product(product: DJIBaseProduct, connectivityChanged isConnected: Bool) {
        if isConnected {
            NSLog("\(String(describing: product.model)) connected. ")
            connectedProduct = product
            ConnectedProductManager.sharedInstance.product = product
            ConnectedProductManager.sharedInstance.setDelegate(delegate: self)
        }
        else {
            NSLog("Product disconnected. ")
            ConnectedProductManager.sharedInstance.connectedProduct = nil
        }
    }
    
    func componentWithKey(withKey key: String, changedFrom oldComponent: DJIBaseComponent?, to newComponent: DJIBaseComponent?) {
        //     (newComponent as? DJICamera)?.delegate = self
        if ((newComponent is DJICamera) == true && (self is DJICameraDelegate) == true) {
            (newComponent as! DJICamera).delegate = self as? DJICameraDelegate
            
        }
        if ((newComponent is DJICamera) == true && (self is DJIPlaybackDelegate) == true) {
            (newComponent as! DJICamera).playbackManager?.delegate = self as? DJIPlaybackDelegate
        }
        
        if ((newComponent is DJIFlightController) == true && (self is DJIFlightControllerDelegate) == true) {
            (newComponent as! DJIFlightController).delegate = self as? DJIFlightControllerDelegate
        }
        
        if ((newComponent is DJIBattery) == true && (self is DJIBatteryDelegate) == true) {
            (newComponent as! DJIBattery).delegate = self as? DJIBatteryDelegate
        }
        
        if ((newComponent is DJIGimbal) == true && (self is DJIGimbalDelegate) == true) {
            (newComponent as! DJIGimbal).delegate = self as? DJIGimbalDelegate
        }
        
        if ((newComponent is DJIRemoteController) == true && (self is DJIRemoteControllerDelegate) == true) {
            (newComponent as! DJIRemoteController).delegate = self as? DJIRemoteControllerDelegate
        }
        
    }
    //this function helps us show message on UI with Ok button
    func showAlertResult(info:String) {
        // create the alert
        var message:String? = info
        
        if info.hasSuffix(":nil") {
            message = "success"
        }
        
        let alert = UIAlertController(title: "Message", message: "\(message ?? "")", preferredStyle: .alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        // show the alert
        if presentedViewController == nil {
            self.present(alert, animated: true, completion: nil)
        } else{
            self.dismiss(animated: false) { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func fetchAircraft() -> DJIAircraft?{
        return ConnectedProductManager.sharedInstance.fetchAircraft()
    }
    
    func fetchCamera() -> DJICamera? {
        return ConnectedProductManager.sharedInstance.fetchCamera()
    }
    
    func fetchGimbal() -> DJIGimbal? {
        return ConnectedProductManager.sharedInstance.fetchGimbal()
    }
    
    func fetchFlightController() -> DJIFlightController? {
        return ConnectedProductManager.sharedInstance.fetchFlightController()
    }
    
    func fetchRemoteController() -> DJIRemoteController? {
        return ConnectedProductManager.sharedInstance.fetchRemoteController()
    }
    
    func fetchBattery() -> DJIBattery? {
        return ConnectedProductManager.sharedInstance.fetchBattery()
    }
    func fetchAirLink() -> DJIAirLink? {
        return ConnectedProductManager.sharedInstance.fetchAirLink()
    }
    func fetchHandheldController() -> DJIHandheldController?{
        return ConnectedProductManager.sharedInstance.fetchHandheldController()
    }
}

