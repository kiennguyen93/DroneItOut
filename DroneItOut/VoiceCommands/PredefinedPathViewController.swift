//
//  PredefinedPathViewController.swift
//  DroneItOut
//
//  Created by Daniel Nguyen on 11/4/17.
//  Copyright © 2017 DJI. All rights reserved.
//

import UIKit
import Foundation
import UIKit
import SpeechKit
import DJISDK
import SpriteKit
import CoreLocation
import CoreBluetooth
class PredefinedPathViewController:  DJIBaseViewController, DJISDKManagerDelegate, SKTransactionDelegate, DJIFlightControllerDelegate, CLLocationManagerDelegate{
  
    var appDelegate = UIApplication.shared.delegate
    //display whether the drone is connected or not
    @IBOutlet weak var connectionStatus: UILabel!
    
    //display text on screen
    @IBOutlet weak var recognitionText: UILabel!

    var ALTITUDE: Float = 3
    var distance: Double?
    var direction: String?
    var strArr: [String] = []
    var d: Int = 0
    
    //SpeechKit variable
    var sksSession: SKSession?
    var sksTransaction: SKTransaction?
    var state = SKSState.sksIdle
    var SKSLanguage = "eng-USA"
    
    //DJI variable
    var connectionProduct: DJIBaseProduct? = nil
    
    //flight Controller
    var fc: DJIFlightController?
    var delegate: DJIFlightControllerDelegate?
    var droneLocation: CLLocationCoordinate2D?
    var aircraftLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var aircraftHeading: CLLocationDegrees = 0
    
    //change DJIFlightControllerCurrentState to DJIFlightControllerState
    var currentState: DJIFlightControllerState?
    var aircraft: DJIAircraft? = nil
    
    //mission variable
    var missionManager: DJIWaypointMissionOperator?
    var locs: [CLLocationCoordinate2D] = []
    var speed: Double = 0
    var currentWaypoint: DJIWaypoint? = nil
    var waypointList: [DJIWaypoint] = []
    var waypointMission = DJIMutableWaypointMission()
    var missionOperator: DJIWaypointMissionOperator? {
        return DJISDKManager.missionControl()?.waypointMissionOperator()
    }
  
    //label name for debugging
    @IBOutlet weak var directionText: UILabel!
    @IBOutlet weak var distanceText: UILabel!
    @IBOutlet weak var positionLatText: UILabel!
    @IBOutlet weak var positionLonText: UILabel!
    @IBOutlet weak var stateText: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // my nuance sandbox credentials
        let SKSAppKey = "e44c885455471dd09b1cef28fae758e80348e989db7b28e4b794a9608cfbfb714783c59dcae26d66fe5c8ef843e7e0462fc9cf0a44f7eefc8b985c18935789da";         //start a session
        let SKSAppId = "NMDPTRIAL_danieltn91_gmail_com20170911202728";
        let SKSServerHost = "sslsandbox-nmdp.nuancemobility.net";
        let SKSServerPort = "443";
        
        let SKSServerUrl = "nmsps://\(SKSAppId)@\(SKSServerHost):\(SKSServerPort)"
        
        // start nuance session with my account
        sksSession = SKSession(url: URL(string: SKSServerUrl), appToken: SKSAppKey)
        sksTransaction = nil
        
        //sksTransaction = sksSession!.recognize(withType: SKTransactionSpeechTypeDictation,detection: .short, language: SKSLanguage, delegate: self)
        
        //Register
        DJISDKManager.registerApp(with: self)
        
        //Connect to product
        DJISDKManager.product()
        checkProductConnected()
       
        let aircraft: DJIAircraft? = self.fetchAircraft()
        if aircraft != nil {
            aircraft!.delegate = self
            aircraft!.flightController?.delegate = self
        }
        //beign listening to user and this gets called repeatedly to ensure countinue listening
        beginApp()
    }
    override func viewWillAppear(_ animated: Bool) {
        guard let connectedKey = DJIProductKey(param: DJIParamConnection) else {
            NSLog("Error creating the connectedKey")
            return;
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            DJISDKManager.keyManager()?.startListeningForChanges(on: connectedKey, withListener: self, andUpdate: { (oldValue: DJIKeyedValue?, newValue : DJIKeyedValue?) in
                if newValue != nil {
                    if newValue!.boolValue {
                        // At this point, a product is connected so we can show it.
                        
                        // UI goes on MT.
                        DispatchQueue.main.async {
                            DJISDKManager.product()
                        }
                    }
                }
            })
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        DJISDKManager.keyManager()?.stopAllListening(ofListeners: self)
    }
    func checkProductConnected() {
        //Display conneciton status
        if ConnectedProductManager.sharedInstance.product != nil {
            connectionStatus.text = "Connected"
            connectionStatus.textColor = UIColor.green
        }
        else {
            connectionStatus.text = "Disconnected"
            connectionStatus.textColor = UIColor.red
        }
    }
    func flightController(_ fc: DJIFlightController, didUpdateSystemState state: DJIFlightControllerState) {
        aircraftLocation = (state.aircraftLocation?.coordinate)!
        aircraftHeading = (fc.compass?.heading)!
        positionLonText.text = "Altitude: " + String(state.altitude) + " m"
    }
    
    enum SKSState {
        case sksIdle
        case sksListening
        case sksProcessing
    }
    //conform DJIApp Protocol delegate and check error
    @objc func appRegisteredWithError(_ error: Error?){
        guard error == nil  else {
            print("Error:\(error!.localizedDescription)")
            return
        }
    }
    //auto make transactons
    func beginApp() {
        switch state {
        case .sksIdle:
            reconize()
        case .sksListening:
            stopRecording()
        case .sksProcessing:
            cancel()
        }
    }
    //refesh transaction and start listening
    @IBAction func refeshButton(_ sender: Any) {
        let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PredefinedPathViewController")
        UIApplication.topViewController()?.present(newViewController, animated: true, completion: nil)
    }
    func reconize(){
        //begin to listening to user
        let options = [
            "" : ""
        ]
        sksTransaction = sksSession?.recognize(withType: SKTransactionSpeechTypeDictation, detection: .long, language: "eng-USA", options: options, delegate: self)
        print("starting reconition process")
    }
    func stopRecording(){
        //Stop recording user
        sksTransaction!.stopRecording()
        beginApp()
        print("Stop Recording")
    }
    func cancel (){
        //cancel transactions
        sksTransaction!.cancel()
        print("cancel recongition transactions")
        beginApp()
    }
    // SKTransactionDelegate
    func transactionDidBeginRecording(_ transaction: SKTransaction!) {
        //transactions begin recording
        state = .sksListening
        stateText.text = "Listening"
        print("begin recording")
    }
    func transactionDidFinishRecording(_ transaction: SKTransaction!) {
        state = .sksProcessing
        stateText.text = "Processing"
        print("finished recording")
    }
    func transaction(_ transaction: SKTransaction!, didFinishWithSuggestion suggestion: String!) {
        state = .sksIdle
        stateText.text = "Idle"
        sksTransaction = nil
        print("reset transaction")
        //beginApp()
    }
    private func transaction(_ transaction: SKTransaction!, didFailWithError error: NSError!, suggestion: String!) {
        print("there is an error in processing speech transaction")
        state = .sksIdle
        stateText.text = "Idle"
        sksTransaction = nil
        beginApp()
    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
    }
    // *************This is where the action happens after speech has been reconized!*********** //
    func transaction(_ transaction: SKTransaction!, didReceive recognition: SKRecognition!) {
        
        state = .sksIdle
        stateText.text = "Idle"
        //convert all text to lowercase
        
        //make an array of word said
        var words = recognition.text.lowercased()
        strArr = words.characters.split{$0 == " "}.map(String.init)
        
        if strArr[0] == "goal" {
            strArr[0] = "go"
        }
        if strArr[0] == "alright" {
            strArr[0] = "go"
            strArr.append("right")
        }
        if strArr.count == 2 || strArr.count == 3{
            if strArr[0] == "call" {
                strArr[0] = "go"
            }
            if strArr[1] == "ride" {
                strArr[1] = "right"
            }
            if strArr[1] == "let" {
                strArr[1] = "left"
            }
        }
        if strArr.count == 3 { // go for work
            if strArr[0] == "call" {
                strArr[0] = "go"
            }
            if strArr[2] == "to" || strArr[2] == "by" || strArr[2] == "for" {
                strArr.remove(at: 2)
            }
            if strArr[1] == "for" && strArr[2] == "work" {
                
                strArr[1] = "forward"
                strArr.remove(at: strArr.index(of: "work")!)
                
            }
            if strArr[1] == "back" && strArr[2] == "work" {
                strArr[1] = "backward"
                strArr.remove(at: strArr.index(of: "work")!)
            }
        }
        
        let joinwords = strArr.joined(separator: " ")
        recognitionText.text = joinwords
        print("recognition recieved: \(recognition.text)")
        print("state: \(state)")
        
        //nuance catches 1 as "one", so we need to change it
        if #available(iOS 9.0, *) {
            if words.localizedStandardRange(of: "one") != nil {
                words = words.replacingOccurrences(of: "one", with: "1")
            }
        } else {
            // Fallback on earlier versions
        }
        
        // set and ensure fc is flight controller
        let fc = (DJISDKManager.product() as! DJIAircraft).flightController
        fc?.delegate = self
        
        //loop through all words
        for str in strArr{
            // say "land" to make the drone land
            if str == "land" {
                land(fc)
            }
            //say "disable" to disable virtual stick mode
            if str == "disable" {
                disableVirtualStickModeSaid()
            }
            //say "execute" to executeMission
            if str == "start" {
                executeMission()
            }
            // say "cancel" to cancel mission
            if str == "cancel" {
                stopWaypointMissioin()
            }
            // say "stop" to stop mission
            if str == "stop" {
                stopWaypointMissioin()
            }
            // say "resume" to resume mission
            if str == "resume" {
                resumeMissionSaid()
            }
        }
        if strArr.count > 1{
            //take off
            if strArr[0] == "take" && strArr[1] == "off" {
                takeOff(fc)
            }
            //set boudary limit height and radius within 20m
            if strArr[0] == "limit" && isNumber(stringToTest: strArr[1]) == true{
                enableMaxFlightRadius(fc,dist: strArr[1])
            }
            if (strArr[0] == "up" || strArr[0] == "down" || strArr[0] == "left" || strArr[0] == "right") && self.isStringAnDouble(string: strArr[1]) {
                direction = strArr[0]
                distance = Double(strArr[1])
                
                //set to label
                directionText.text = direction
                distanceText.text = "\(distance)"
                runLongCommands(dir: direction!, dist: distance!)
            }
            // say "goHome" to make the drone land
            if strArr[0] == "go" {
                if strArr[1] == "home"{
                    goHome(fc)
                }
            }
        }
        else {
            self.showAlertResult(info: "Command not found, say your next command!")
        }
    }
    func isStringAnDouble(string: String) -> Bool {
        return Double(string) != nil
    }
    
    //******** RUN COMMANDS METHODS **********//

    func runLongCommands(dir: String, dist: Double){
        //by here, we have each command being seperated into direction, distance, units
        // next steps are find location, distance and direction of drone
        
        // 5 mission paramenter always needed
        self.waypointMission.maxFlightSpeed = 2
        self.waypointMission.autoFlightSpeed = 1
        self.waypointMission.headingMode = DJIWaypointMissionHeadingMode.auto
        self.waypointMission.flightPathMode = DJIWaypointMissionFlightPathMode.curved
        waypointMission.finishedAction = DJIWaypointMissionFinishedAction.noAction
        
        //get drone's location
        guard let locationKey = DJIFlightControllerKey(param: DJIFlightControllerParamAircraftLocation) else {
            return
        }
        guard let droneLocationValue = DJISDKManager.keyManager()?.getValueFor(locationKey) else {
            return
        }
        //convert CLLocation to CLLocationCoordinate2D
        let droneLocation0 = droneLocationValue.value as! CLLocation
        self.droneLocation = droneLocation0.coordinate
        //self.droneLocation = currentState?.aircraftLocation?
        
        var lat: Double = droneLocation!.latitude
        var long: Double = droneLocation!.longitude
        
        //add first waypoint
        let loc1 = CLLocationCoordinate2DMake(lat, long)
        currentWaypoint = DJIWaypoint(coordinate: loc1)
        currentWaypoint?.altitude = Float(droneLocation0.altitude)
        self.waypointMission.add(currentWaypoint!)
        //if units are in meters
        //convert all unit to GPS coordinate points
        
        if dir == "up"{
            //long = long + convertMetersToPoint(m: dist)
            ALTITUDE = Float(droneLocation0.altitude) + Float(dist)
        }
        if dir == "down" {
            //long = long - convertMetersToPoint(m: dist)
            ALTITUDE = Float(droneLocation0.altitude) - Float(dist)
        }
        if dir == "right"{
            lat = lat + convertMetersToPointLat(m: dist)
        }
        if dir == "left"{
            lat = lat - convertMetersToPointLat(m: dist)
        }
        
        //this is second waypoint
        var commLoc: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0)
        commLoc.latitude = lat
        commLoc.longitude = long
        positionLatText.text = "\(commLoc.latitude)"
        positionLonText.text = "\(commLoc.longitude)"
        print("position now is " + String(describing: commLoc) )
        
        if CLLocationCoordinate2DIsValid(commLoc) {
            let waypoint2: DJIWaypoint = DJIWaypoint(coordinate: commLoc)
            waypoint2.altitude = ALTITUDE
             waypointList.append(waypoint2)
            self.waypointMission.add(waypoint2)
        }
       
        
    }
    
    //disable Virtual Stick Mode so you can use remote control
    func disableVirtualStickModeSaid() {
        fc?.setVirtualStickModeEnabled(false, withCompletion: { (error: Error?) in
            if error != nil {
                self.showAlertResult(info: "Error Disable Virtual Stick Mode ")
            }
            else {
                self.showAlertResult(info: "virtual stick mode is disabled")
                var commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                //Here is where data gets changed
                commandCtrlData?.pitch = 0
                commandCtrlData?.roll = 0
                commandCtrlData?.yaw = 0
                commandCtrlData?.verticalThrottle = 0
              
            }
        })
    }
    func pauseMissionSaid(){
        missionOperator?.pauseMission(completion: { (error: Error?) in
            if error != nil {
                self.showAlertResult(info: "Error pause mission " + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Mission pause sucessfully!")
            }
        })
    }
    func stopWaypointMissioin(){
        missionOperator?.stopMission(completion: { (error: Error?) in
            if error != nil {
                self.showAlertResult(info: "Error stop mission " + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Mission stoped sucessfully!")
            }
        })
    }
    func resumeMissionSaid(){
        missionOperator?.resumeMission(completion: { (error: Error?) in
            if error != nil {
                self.showAlertResult(info: "Error resume mission " + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Mission resume sucessfully!")
            }
        })
    }
    func executeMission(){
        //prepare mission
        prepareMission(missionName: self.waypointMission)
    }
    func prepareMission(missionName: DJIWaypointMission){
        let error = missionName.checkParameters()
        if error != nil {
            showAlertResult(info: "Waypoint Mission parameters are invalid: \(String(describing: error))")
            return
        }
        else {
            showAlertResult(info: "Validated Mission's Waypoints")
        }
        
        print("Mission prepared!")
        func didMissionUpload(error: Error?){
            
            if error != nil {
                self.showAlertResult(info: "Error uploading mission: " + (error?.localizedDescription)!)
                print("error uploading mission: " + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Uploading mission sucessfully, starting mission..!")
                print("uploading mission successfil, starting mission..!")
                // start mission
                missionOperator?.startMission(completion: didMissionStart)
            }
        }
        func didMissionStart(error: Error?) {
            
            if error != nil {
                self.showAlertResult(info: "Error starting waypoint mission: " + (error?.localizedDescription)!)
                print("Error starting waypoint mission: " + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Start mission succesfully")
                print("Start Mission sucess")
            }
        }
        missionOperator?.load(missionName)
        // Upload the mission and then execute it
        missionOperator?.addListener(toUploadEvent: self, with: DispatchQueue.main, andBlock: {(event) in
            if event.error != nil {
                self.showAlertResult(info: "There was an error trying to upload the mission, trying again")
                print("There was an error trying to upload the mission, trying again")
                self.missionOperator?.uploadMission(completion: didMissionUpload)
            }
            else {
                self.showAlertResult(info:"Mission was uploaded, Starting mission")
                print("Mission was uploaded, Starting mission")
                // start mission
                self.missionOperator?.startMission(completion: didMissionStart )
            }
        })
        missionOperator?.uploadMission(completion: didMissionUpload)
    }
    func convertMetersToPoint(m: Double) -> Double{
        var lonO:Double = 0.0
        //Earth’s radius, sphere
        let R:Double = 6378137.0
        //Coordinate offsets in radians
        let pi:Double = Double.pi
        let lat = 51.0
        let dLon:Double = m / (R * cos(pi * lat / 180))
        
        lonO = dLon * 180/pi
        return lonO
    }
    func convertMetersToPointLat(m: Double) -> Double{
        //111 km = 1 lat
        ///111 m = 0.001 lat
        let lat0:Double = (m * 0.001)/111
        return lat0
    }
    func isNumber(stringToTest : String) -> Bool {
        let numberCharacters = CharacterSet.decimalDigits.inverted
        return !stringToTest.isEmpty && stringToTest.rangeOfCharacter(from:numberCharacters) == nil
    }
    
    //************ Flight Controller Drone Method *****************//
    func takeOff(_ fc: DJIFlightController!) {
        if fc != nil {
            
            //fc!.takeoff(completion: {[weak self](error: Error?) -> Void in
            //replace takoff to startTakeoff
            fc.startTakeoff(completion: {[weak self](error: Error?) -> Void in
                if error != nil {
                    self?.showAlertResult(info: "TakeOff Error: \(error!.localizedDescription)")
                }
                else {
                    self?.showAlertResult(info: "TakeOff Succeeded.")
                }
            })
        }
        else {
            self.showAlertResult(info: "Take Off Component not existed")
        }
    }
    func goHome(_ fc: DJIFlightController!) {
        if fc != nil {
            //changed autoLanding() to startLanding()
            fc!.startGoHome(completion: {[weak self](error: Error?) -> Void in
                if error != nil {
                    self?.showAlertResult(info: "Go Home Error: \(error!.localizedDescription)")
                }
                else {
                    self?.showAlertResult(info: "Go Home Succeeded.")
                }
            })
        }
        else {
            self.showAlertResult(info: "Go Home Component not existed")
        }
    }
    func land(_ fc: DJIFlightController!) {
        if fc != nil {
            //changed autoLanding() to startLanding()
            fc!.startLanding(completion: {[weak self](error: Error?) -> Void in
                if error != nil {
                    self?.showAlertResult(info: "Auto Landing Error: \(error!.localizedDescription)")
                }
                else {
                    self?.showAlertResult(info: "Auto Landing Succeeded.")
                }
            })
        }
        else {
            self.showAlertResult(info: "Land Component not existed")
        }
    }
    func stopPropellers(_ fc: DJIFlightController!) {
        if fc != nil {
            fc!.startLanding(completion: {[weak self](error: Error?) -> Void in
                if error != nil {
                    self?.showAlertResult(info: "Turn Off Error: \(error!.localizedDescription)")
                }
                else {
                    self?.showAlertResult(info: "Turn Off Succeeded.")
                }
            })
        }
        else {
            self.showAlertResult(info: "Turn Off Component not existed")
        }
    }
    //set maximum height
    func setMaxFlightHeight(_ fc: DJIFlightController!, distance: Float) {
        fc.setMaxFlightHeight(distance, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Height Error: \(error!.localizedDescription)")
                print("Max Height Error: \(error!.localizedDescription)")
            }
        })
    }
    //set maximum radius
    func setMaxFlightRadius(_ fc: DJIFlightController!, distance: Float) {
        fc.setMaxFlightRadius(distance, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Radius Error: \(error!.localizedDescription)")
                print("Max Radius Error: \(error!.localizedDescription)")
            }
        })
    }
    func enableMaxFlightRadius(_ fc: DJIFlightController!, dist: String) {
        let distance = Float(dist)
        fc.setMaxFlightRadiusLimitationEnabled(true, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Enable Max Flight Radius Error: \(error!.localizedDescription)")
            }
            else {
                self?.setMaxFlightHeight(fc,distance: distance!)
                self?.setMaxFlightRadius(fc,distance: distance!)
                self?.showAlertResult(info: "Enable Max Flight Radius successful")
            }
        })
    }
    func productConnected() {
        guard let newProduct = DJISDKManager.product() else {
            NSLog("Product is connected but DJISDKManager.product is nil -> something is wrong")
            return;
        }
    }
    func productDisconnected() {
        NSLog("Product Disconnected")
    }
}

