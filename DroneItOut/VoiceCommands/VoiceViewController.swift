//
//  ViewController.swift
//  DroneItOut
//
//  Created by Daniel Nguyen on 9/16/17.
//  Copyright © 2017 DJI. All rights reserved.
//
import Foundation
import UIKit
import SpeechKit
import DJISDK
import SpriteKit
import CoreLocation
import CoreBluetooth

class VoiceViewController:  DJIBaseViewController, DJISDKManagerDelegate, SKTransactionDelegate, DJIFlightControllerDelegate, CLLocationManagerDelegate {
    
    //get instance of Objective-C class to call methods
    let instanceOfDJIRootViewControllert: DJIRootViewController = DJIRootViewController()
    //objective-C object
    let instanceofFollowMeViewController: FollowMeViewController = FollowMeViewController()
    
    //weak var appDelegate: AppDelegate! = UIApplication.shared.delegate as? AppDelegate
    
    var appDelegate = UIApplication.shared.delegate

    //display whether the drone is connected or not
    @IBOutlet weak var connectionStatus: UILabel!
    
    //display text on screen
    @IBOutlet weak var recognitionText: UILabel!
    
    let pointOffset: Double = 0.000179863
    //1 = 10m
    //1 m = 3.280399 ft
    //1 ft = 0.3048 m
    
    //Calculation 1m = GPS point - 0.000284
    let myPointOffset: Double = 0.0000181
    var ALTITUDE: Float = 2
    var distance: Double?
    var direction: String = ""
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
    
    var hotpointMission: DJIHotpointMission = DJIHotpointMission()
    var mCurrentHotPointCoordinate: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var locs: [CLLocationCoordinate2D] = []
    var uploadStatus: Float = 0
    var commands: [String] = []
    var speed: Double = 0
    
    //store coordinate that uses to create waypoint mission
    var waypointList: [DJIWaypoint] = []
    var waypointMission = DJIMutableWaypointMission()
    //var mission = DJIMutableWaypointMission()
    var missionOperator: DJIWaypointMissionOperator? {
        return DJISDKManager.missionControl()?.waypointMissionOperator()
    }
    
    var customMission: DJICustomMission? = nil
    var missionSetup: Bool = false
    var deltaProcess: CGFloat = 0
    //var allSteps: [DJIMissionStep] = []
    var stepIndex: Int = 0
    
    //mission status UI bar
    @IBOutlet weak var missionStatusBar: UIProgressView!
    
    //label name for debugging
    @IBOutlet weak var VSMText: UILabel!
    @IBOutlet weak var commandText: UILabel!
    @IBOutlet weak var directionText: UILabel!
    @IBOutlet weak var distanceText: UILabel!
    @IBOutlet weak var unitText: UILabel!
    @IBOutlet weak var positionLatText: UILabel!
    @IBOutlet weak var positionLonText: UILabel!
    @IBOutlet weak var stateText: UILabel!
    
    @IBOutlet weak var predefinedButton: UIButton!
    @IBAction func loadPredefinedPathsView(_ sender: UIButton)
    {
        performSegue(withIdentifier: "VoiceToPathsSegue", sender: Any?.self)
    }
    @IBAction func loadRootView(_ sender: UIButton)
    {
        performSegue(withIdentifier: "VoiceToRootViewSegue", sender: Any?.self)
    }
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
        //sksTransaction = nil
        
       // sksTransaction = sksSession!.recognize(withType: SKTransactionSpeechTypeDictation,detection: .short, language: SKSLanguage, delegate: self)
        
        //Register
        DJISDKManager.registerApp(with: self)
        
        //Connect to product
        DJISDKManager.product()
        checkProductConnected()
        ConnectedProductManager.sharedInstance.fetchAirLink()
      
        let aircraft: DJIAircraft? = self.fetchAircraft()
        if aircraft != nil {
            aircraft!.delegate = self
            aircraft!.flightController?.delegate = self
        }
        
        missionStatusBar.setProgress(0, animated: true)
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
        sksTransaction?.cancel()
        sksTransaction?.stopRecording()
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
        //reload application data (renew root view )
       // let storyboard = UIStoryboard(name: "Main", bundle: nil)
       // UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "VoiceViewController")
        
        let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VoiceViewController")
        UIApplication.topViewController()?.present(newViewController, animated: true, completion: nil)

    }
    func reconize(){
        //begin to listening to user
        let options = [
            "" : ""
        ]
        sksTransaction = sksSession?.recognize(withType: SKTransactionSpeechTypeDictation, detection: .short, language: "eng-USA", options: options, delegate: self)
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
        beginApp()
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
        if strArr.count == 2{
            if strArr[0] == "call" {
                strArr[0] = "go"
            }
            if strArr[1] == "ride" {
                strArr[1] = "right"
            }
            if strArr[1] == "let" {
                strArr[1] = "left"
            }
            if strArr[1] == "check"{
                strArr[1] = "take"
            }
        }
        if strArr.count == 3 { // go for work
            if strArr[0] == "call" {
                strArr[0] = "go"
            }
            if strArr[2] == "to" || strArr[2] == "by" || strArr[2] == "for" {
                strArr.remove(at: 2)
            }
            if strArr[1] == "ride" {
                strArr[1] = "right"
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
        if strArr.count == 4 {
            if strArr[1] == "ride" {
                strArr[1] = "right"
            }
            if strArr[1] == "let" {
                strArr[1] = "left"
            }
        }
       
        let joinwords = strArr.joined(separator: " ")
        recognitionText.text = joinwords
        print("recognition recieved: \(recognition.text)")
        print("state: \(state)")
        state = .sksIdle
        stateText.text = "Idle"
        
        //nuance catches 1 as "one", so we need to change it
        if #available(iOS 9.0, *) {
            if words.localizedStandardRange(of: "one") != nil {
                words = words.replacingOccurrences(of: "one", with: "1")
            }
        } else {
            // Fallback on earlier versions
        }
        
        // set and ensure fc is flight controller
        if let fc = (DJISDKManager.product() as! DJIAircraft).flightController {
            fc.delegate = self
        }
        
        //loop through all words
        for str in strArr{
            
            // say "land" to make the drone land
            if str == "land" {
                land(fc)
            }
            //say "enable" to enable virtual stick mode
            if str == "enable" {
                enableVirtualStickModeSaid()
            }
            //say "disable" to disable virtual stick mode
            if str == "disable" {
                disableVirtualStickModeSaid()
            }
            //say "execute" to executeMission
            if str == "execute" {
                executeMission()
            }
            // say "cancel" to cancel mission
            if str == "cancel" {
               stopWaypointMissioin()
                VSMText.text = "Mission cancelled"
            }
            // say "stop" to stop mission
            if str == "stop" {
                stopWaypointMissioin()
            }
            // say "resume" to resume mission
            if str == "resume" {
                resumeMissionSaid()
                VSMText.text = "Mission resume"
            }
            //say "remove" to remove all listeners
            if str == "remove" {
                missionOperator?.removeAllListeners()
            }
            //say "waypoints" to predefine paths
            if str == "waypoints" {
               // predefinedPath()
                
                transaction.cancel()
                transaction.stopRecording()
                let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PredefinedPathViewController")
                UIApplication.topViewController()?.present(newViewController, animated: true, completion: nil)
                
            }
        }
        if strArr.count > 1 && strArr.count < 3{
            
            //take off
            if strArr[0] == "take" && strArr[1] == "off" {
                takeOff(fc)
            }
            if strArr[0] == "follow" && strArr[1] == "me" {
                followMe()
            }
            if strArr[0] == "stop" && strArr[1] == "follow" {
                stopFollow()
            }
            // say "goHome" to make the drone land
            if strArr[0] == "go" {
                if strArr[1] == "home"{
                    goHome(fc)
                }
                if strArr[1] == "up" {
                    direction = "up"
                    //runShortMovementCommands()
                }
                if strArr[1] == "down" {
                    direction = "down"
                   // runShortMovementCommands()
                }
                if strArr[1] == "left" {
                    direction = "left"
                    //runShortMovementCommands()
                }
                if strArr[1] == "right" {
                    direction = "right"
                    //runShortMovementCommands()
                }
                if strArr[1] == "forward" {
                    direction = "forward"
                    //runShortMovementCommands()
                }
                if strArr[1] == "backward" {
                    direction = "backward"
                   // runShortMovementCommands()
                }
            }
            // say in distance
            switch strArr[0] {
            case "one":strArr[0] = "1"
            case "two":strArr[0] = "2"
            case "to":strArr[0] = "2"
            case "three":strArr[0] = "3"
            case "four":strArr[0] = "4"
            case "five":strArr[0] = "5"
            case "six":strArr[0] = "6"
            case "seven":strArr[0] = "7"
            case "eight":strArr[0] = "8"
            case "nine":strArr[0] = "9"
            case "ten":strArr[0] = "10"
            default:
                break
            }
            if(direction.isEmpty){
                print("skip")
            }
            else if self.isStringAnDouble(string: strArr[0]) {
                distance = Double(strArr[0])
                //set to label
                distanceText.text = "\(String(describing: distance))"
                runLongCommands(dir: direction, dist: distance!)
            }
        }
            //Exmple: Go north 5 m, or go up 5 ,
        else if strArr.count > 2{
            //check if strArr[2] is Int
            // if isStringAnInt(string: strArr[2])
            // if the speech match with "go [up, down, left, right, forward, backward, north, south, west, east] [Digit] [m,meter,meters]
            if (strArr[0] == "go" && (strArr[1] == "north" || strArr[1] == "south" || strArr[1] == "west" || strArr[1] == "east" || strArr[1] == "up" || strArr[1] == "down" || strArr[1] == "left" || strArr[1] == "right" || strArr[1] == "backward" || strArr[1] == "forward") && self.isStringAnDouble(string: strArr[2]) == true && (strArr[3] == "m" || strArr[3] == "meter" || strArr[3] == "meters")) {
                direction = strArr[1]
                distance = Double(strArr[2])
                
                //set to label
                directionText.text = direction
                distanceText.text = "\(String(describing: distance))"
                
                runLongCommands(dir: direction, dist: distance!)
            }
           //set boudary limit height and radius within 20m
            else if  strArr[0] == "limit" && isNumber(stringToTest: strArr[1]) == true && strArr[2] == "m"{
                enableMaxFlightRadius(fc,dist: strArr[1])
            }
            else {
                self.showAlertResult(info: "Command not found, say your next command!")
            }
        }
    }
    func isStringAnDouble(string: String) -> Bool {
        return Double(string) != nil
    }
    
    //******** RUN COMMANDS METHODS **********//
    func followMe(){
        instanceofFollowMeViewController.callStartFollowMe()
    }
    func stopFollow(){
        instanceofFollowMeViewController.callStopFollowMe()
    }
    func runShortMovementCommands() {
        enableVirtualStickModeSaid()
        var direction: String = ""
        print("Short commands: \(commands)")
        if strArr.count == 2 { //Go up
            direction = strArr[1]
            distanceText.text = "\(direction)"
        }
        
        //initalize a data object. They have pitch, roll, yaw, and throttle
        var commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
        //flightCtrlData?.pitch = 0.5 - make it goes to the right a little bit 0.5m/s
        //Here is where data gets changed
        //commandCtrlData?.pitch = 0
        //commandCtrlData?.roll = 0
        //commandCtrlData?.yaw = 0
        //commandCtrlData?.verticalThrottle = 0
        
        if direction == "left" {
            directionText.text = "left"
            commandCtrlData?.roll = -1.0
        }
        if direction == "right" {
            commandCtrlData?.roll = 1.0
            directionText.text = "right"
        }
        if direction == "up" {
            commandCtrlData?.verticalThrottle = 1.0
            directionText.text = "up"
        }
        if direction == "down" {
            commandCtrlData?.verticalThrottle = -1.0
            directionText.text = "down"
        }
        if direction == "forward" {
            commandCtrlData?.pitch = 1.0
            directionText.text = "forward"
        }
        if direction == "backward"{
            commandCtrlData?.pitch = -1.0
            directionText.text = "backward"
        }
        // enable Virtual Stick Mode which it disable function on remote control
        enterVirtualStickMode( newFlightCtrlData: commandCtrlData!)
        
    }
    
    func enterVirtualStickMode( newFlightCtrlData: DJIVirtualStickFlightControlData) {
        //cancel the missions just in case they are running
        //stopWaypointMissioin()
        
        fc = self.fetchFlightController()
        fc?.delegate = self
        
        if fc != nil {
            //First, you must enable virtual control stick mode,then send virtual stick commands
            fc?.getVirtualStickModeEnabled(completion: {(true, error: Error?)  ->Void in
                if error != nil {
                    self.VSMText.text = "virtual stick mode is not enabled: \(String(describing: error))"
                }
                else {
                    self.VSMText.text = "virtual stick mode enabled"
                    
                    self.fc?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                    self.fc?.rollPitchControlMode = DJIVirtualStickRollPitchControlMode.velocity
                    self.fc?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
                    
                    self.fc?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.ground
                    //self.fc?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
                    
                    var flightCtrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData.init()
                    
                    //Flight data gets changed
                    flightCtrlData.pitch = newFlightCtrlData.pitch
                    flightCtrlData.roll = newFlightCtrlData.roll
                    flightCtrlData.yaw = newFlightCtrlData.yaw
                    flightCtrlData.verticalThrottle = newFlightCtrlData.verticalThrottle
                    
                    //if VirtualStickControlMode is available, the data will be sent and drone will perfom command
                    //if (self.fc?.isVirtualStickControlModeAvailable())! {
                        self.fc?.send(flightCtrlData, withCompletion: {(error: Error?) -> Void in
                            if error != nil {
                                self.VSMText.text = "could not send data: \(String(describing: error))"
                            }
                            else {
                                self.VSMText.text = "Data was sent"
                            }
                        })
                    //}
                   // else {
                    //    self.VSMText.text = "VSC mode is unavailable"
                   // }
                }
            })
        }
    }
    
    func runLongCommands(dir: String, dist: Double){
        //by here, we have each command being seperated into direction, distance, units
        // next steps are find location, distance and direction of drone
        disableVirtualStickModeSaid()
        // cancelMissionSaid()
        self.waypointMission.removeAllWaypoints()
        waypointMission = DJIMutableWaypointMission()
        
        // 5 mission paramenter always needed
        self.waypointMission.maxFlightSpeed = 2
        self.waypointMission.autoFlightSpeed = 1
        self.waypointMission.headingMode = DJIWaypointMissionHeadingMode.auto
        self.waypointMission.flightPathMode = DJIWaypointMissionFlightPathMode.normal
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
        //let loc1 = CLLocationCoordinate2DMake((droneLocation?.latitude)! + myPointOffset, (droneLocation?.longitude)!)
        let loc1 = CLLocationCoordinate2DMake(lat, long)
        let waypoint: DJIWaypoint = DJIWaypoint(coordinate: loc1)
        waypoint.altitude = Float(droneLocation0.altitude)
        self.waypointMission.add(waypoint)
        
        //if units are in meters
        //convert all unit to GPS coordinate points
        
        if dir == "east" || dir == "up"{
            //long = long + convertMetersToPoint(m: dist)
            ALTITUDE = Float(droneLocation0.altitude) + Float(dist)
        }
        if dir == "west" || dir == "down" {
            //long = long - convertMetersToPoint(m: dist)
            ALTITUDE = Float(droneLocation0.altitude) - Float(dist)
        }
        if dir == "noth" || dir == "right"{
            lat = lat + convertMetersToPointLat(m: dist)
        }
        if dir == "south" || dir == "left"{
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
            waypoint2.heading = 0
            waypoint2.actionTimeoutInSeconds = 60
            waypoint2.cornerRadiusInMeters = 5
            //wpoint2.turnMode = .clockwise
            waypoint2.gimbalPitch = 0
            
            self.waypointMission.add(waypoint2)
            
        }
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
                missionOperator?.removeAllListeners()
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
    func predefinedPath() {
        disableVirtualStickModeSaid()
        // cancelMissionSaid()
        self.waypointMission.removeAllWaypoints()
        waypointMission = DJIMutableWaypointMission()
        
        
        // 5 mission paramenter always needed
        waypointMission.maxFlightSpeed = 2
        waypointMission.autoFlightSpeed = 1
        waypointMission.headingMode = .auto
        waypointMission.rotateGimbalPitch = true
        waypointMission.flightPathMode = .curved
        waypointMission.finishedAction = .noAction
        waypointMission.gotoFirstWaypointMode = .pointToPoint
        
        //get drone's location
        guard let locationKey = DJIFlightControllerKey(param: DJIFlightControllerParamAircraftLocation) else {
            return
        }
        guard let droneLocationValue = DJISDKManager.keyManager()?.getValueFor(locationKey) else {
            return
        }
        
        //convert CLLocation to CLLocationCoordinate2D
        let droneLocation0 = droneLocationValue.value as! CLLocation
        let droneLocation = droneLocation0.coordinate
        //self.droneLocation = currentState?.aircraftLocation?
        
        var lat: Double = droneLocation.latitude
        var long: Double = droneLocation.longitude
        
        waypointMission.pointOfInterest = droneLocation
        let offset = 0.0000899322
        
        let loc1 = CLLocationCoordinate2DMake(lat, long)
        let currentWaypoint = DJIWaypoint(coordinate: loc1)
        currentWaypoint.altitude = Float(droneLocation0.altitude)
        currentWaypoint.heading = 0
        currentWaypoint.actionTimeoutInSeconds = 60
        currentWaypoint.cornerRadiusInMeters = 5
        currentWaypoint.turnMode = .clockwise
        currentWaypoint.gimbalPitch = 0
        
        
        //add second waypoint
        let loc2 = CLLocationCoordinate2DMake(lat, long)
        let wpoint2 = DJIWaypoint(coordinate: loc2)
        wpoint2.altitude = Float((droneLocation0.altitude) + 2)
        wpoint2.heading = 0
        wpoint2.actionTimeoutInSeconds = 60
        wpoint2.cornerRadiusInMeters = 5
        wpoint2.turnMode = .clockwise
        wpoint2.gimbalPitch = 0
        
        
        //add third waypoint
        lat = lat + myPointOffset
        let loc3 = CLLocationCoordinate2DMake(lat, long)
        let wpoint3 = DJIWaypoint(coordinate: loc3)
        wpoint3.altitude =  wpoint2.altitude
        wpoint3.heading = 0
        wpoint3.actionTimeoutInSeconds = 60
        wpoint3.cornerRadiusInMeters = 5
        wpoint3.turnMode = .clockwise
        wpoint3.gimbalPitch = -90
        
        
        //add 4th waypoint
        let loc4 = CLLocationCoordinate2DMake(lat, long)
        let wpoint4 = DJIWaypoint(coordinate: loc4)
        wpoint4.altitude =  (currentWaypoint.altitude) - 2
        wpoint4.heading = 0
        wpoint4.actionTimeoutInSeconds = 60
        wpoint4.cornerRadiusInMeters = 5
        wpoint4.turnMode = .clockwise
        wpoint4.gimbalPitch = 0
        
        
        //add 5th waypoint
        lat = lat + myPointOffset
        let loc5 = CLLocationCoordinate2DMake(lat, long)
        let wpoint5 = DJIWaypoint(coordinate: loc5)
        wpoint5.altitude =  wpoint2.altitude
        wpoint5.heading = 0
        wpoint5.actionTimeoutInSeconds = 60
        wpoint5.cornerRadiusInMeters = 5
        wpoint5.turnMode = .clockwise
        wpoint5.gimbalPitch = -90
  
        //add 6th waypoint
        let loc6 = CLLocationCoordinate2DMake(lat, long)
        let wpoint6 = DJIWaypoint(coordinate: loc6)
        wpoint6.altitude =  (currentWaypoint.altitude) + 2
        wpoint6.heading = 0
        wpoint6.actionTimeoutInSeconds = 60
        wpoint6.cornerRadiusInMeters = 5
        wpoint6.turnMode = .clockwise
        wpoint6.gimbalPitch = 0
        
        //add 7th waypoint
        lat = lat + myPointOffset
        let loc7 = CLLocationCoordinate2DMake(lat , long)
        let wpoint7 = DJIWaypoint(coordinate: loc7)
        wpoint7.altitude = wpoint2.altitude
        wpoint7.heading = 0
        wpoint7.actionTimeoutInSeconds = 60
        wpoint7.cornerRadiusInMeters = 5
        //wpoint7.turnMode = .clockwise
        wpoint7.gimbalPitch = -90
        
        //add 8th waypoint
        let loc8 = CLLocationCoordinate2DMake(lat, long)
        let wpoint8 = DJIWaypoint(coordinate: loc8)
        wpoint8.altitude =  (currentWaypoint.altitude) - 2
        wpoint8.heading = 0
        wpoint8.actionRepeatTimes = 1
        wpoint8.actionTimeoutInSeconds = 60
        wpoint8.cornerRadiusInMeters = 5
        wpoint8.turnMode = .clockwise
        wpoint8.gimbalPitch = 0
        
        //add waypoints to mission
        waypointMission.add(currentWaypoint)
        waypointMission.add(wpoint2)
        waypointMission.add(wpoint3)
        waypointMission.add(wpoint4)
        waypointMission.add(wpoint5)
        waypointMission.add(wpoint6)
        waypointMission.add(wpoint7)
        waypointMission.add(wpoint8)
        
        //prepareMission before execute
        prepareMission(missionName: waypointMission)
    }
    //when virtual stick mode is enabled, user can't control aircraft by remote control
    func enableVirtualStickModeSaid() {
        //replace enableVirtualStickControlMode to setVirtualStickModeEnabled
        fc?.setVirtualStickModeEnabled(true, withCompletion: { (error: Error?) in
            if error != nil {
                self.VSMText.text = "virtual stick mode not enabled: \(String(describing: error))"
                print("VSM: \(String(describing: error))")
            }
            else {
                self.VSMText.text = "virtual stick mode enabled"
                print("VSM: enable")
                //missing some codes
                //initalize a data object. They have pitch, roll, yaw, and throttle
                var commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                commandCtrlData?.pitch = 0
                commandCtrlData?.roll = 0
                commandCtrlData?.yaw = 0
                commandCtrlData?.verticalThrottle = 0
 
                self.commandText.text = "\(String(describing: self.fc?.isVirtualStickControlModeAvailable()))"
                
            }
        })
    }
    
    //disable Virtual Stick Mode so you can use remote control
    func disableVirtualStickModeSaid() {
        fc?.setVirtualStickModeEnabled(false, withCompletion: { (error: Error?) in
            if error != nil {
                self.VSMText.text = "virtual stick mode is not disabled: \(String(describing: error))"
            }
            else {
                self.VSMText.text = "virtual stick mode is disabled"
                var commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                //Here is where data gets changed
                commandCtrlData?.pitch = 0
                commandCtrlData?.roll = 0
                commandCtrlData?.yaw = 0
                commandCtrlData?.verticalThrottle = 0
                
                self.commandText.text = "\(String(describing: self.fc?.isVirtualStickControlModeAvailable()))"
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
        print("Mission executed !")
        missionOperator?.startMission(completion: { (error) in
            if error != nil {
                self.showAlertResult(info: "Start mission error: " + (error?.localizedDescription)!)
                print("Start Mission error !" + (error?.localizedDescription)!)
            }
            else {
                self.showAlertResult(info: "Start mission successful")
                print("Start Mission scuessful !")
            }
        })
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
    func convertMeterToLongitude(m: Double) -> Double{
        // 1 mile = 1609.34 m
        //1m = 0.000621371
        //
        //Latitude: 1 deg = 110.54 km
        //Longitude: 1 deg = 111.320*cos(latitude) km
        let km = m/1000
        let latitudeDegree = km/110.54
        let longitudeDegree = 111.320*cos(latitudeDegree)
        return longitudeDegree
    }
    func convertMeterToLatitude(m: Double) -> Double{
        let km = m/1000
        let latitudeDegree = km/110.54
        return latitudeDegree
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
    func setMaxFlightHeight(_ fc: DJIFlightController!, distance: Float) {
        //set maximum height is 20m
        fc.setMaxFlightHeight(distance, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Height Error: \(error!.localizedDescription)")
            }
        })
    }
    func setMaxFlightRadius(_ fc: DJIFlightController!, distance: Float) {
        //set maximum height is 20m
        fc.setMaxFlightRadius(distance, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Radius Error: \(error!.localizedDescription)")
            }
        })
    }
    func enableMaxFlightRadius(_ fc: DJIFlightController!, dist: String) {
        let distance = Float(dist)
        self.setMaxFlightHeight(fc,distance: distance!)
        self.setMaxFlightRadius(fc,distance: distance!)
        fc.setMaxFlightRadiusLimitationEnabled(true, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Enable Max Flight Radius Error: \(error!.localizedDescription)")
            }
            else {
                
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
extension UIApplication {
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

