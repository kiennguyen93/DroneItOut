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
    let ALTITUDE: Float = 2
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
    @IBOutlet weak var orderText: UILabel!
    @IBOutlet weak var commandText: UILabel!
    @IBOutlet weak var directionText: UILabel!
    @IBOutlet weak var distanceText: UILabel!
    @IBOutlet weak var unitText: UILabel!
    //@IBOutlet weak var htext: UILabel!
    @IBOutlet weak var regexCommandText: UILabel!
    
    @IBOutlet weak var positionText: UILabel!
    
    @IBOutlet weak var directionTest: UILabel!
    @IBOutlet weak var stateText: UILabel!
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
        
        sksTransaction = sksSession!.recognize(withType: SKTransactionSpeechTypeDictation,detection: .short, language: SKSLanguage, delegate: self)
        
        //Register
        DJISDKManager.registerApp(with: self)
        
        //Connect to product
        DJISDKManager.product()
        checkProductConnected()
        ConnectedProductManager.sharedInstance.fetchAirLink()
        
        //mission manner
        //self.missionManager = DJIMissionControl.activeTrackMissionOperator(DJIMissionControl)()!
        //self.missionManager!.delegate = self
        // Setup the flight controller delegate
        
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
        
        positionText.text = "Altitude: " + String(state.altitude) + " m"
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
        
        state = .sksIdle
        stateText.text = "Idle"
        //convert all text to lowercase
        
        
        
        //make an array of word said
        var words = recognition.text.lowercased()
        strArr = words.characters.split{$0 == " "}.map(String.init)
        
        
        if (strArr[0] == "goal") {
            strArr[0] = "go"
        }
        if strArr[0] == "alright" {
            strArr[0] = "go"
            strArr.append("right")
        }
        if strArr.count == 2 {
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
        if strArr.count == 3 {
            if strArr[2] == "to" || strArr[2] == "by" || strArr[2] == "for" {
                strArr.remove(at: 2)
            }
            if strArr[1] == "for" && strArr[2] == "work" {
                strArr[1] = "forward"
                strArr.remove(at: 2)
            }
            if strArr[1] == "back" && strArr[2] == "work" {
                strArr[1] = "backward"
                strArr.remove(at: 2)
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
        
        /*
         fc = fetchFlightController()
         if fc != nil{
         fc!.delegate = self
         }
         */
        /*------------ERROR MAYBE HERE--------------------------------------*/
        /*
         // use regex for NSEW compass direction
         commands = findNSEWCommands(str: words)
         
         if !commands.isEmpty {
         //runNSEWDirectionCommands()
         commands = [] //reset commands array after it's done
         orderText.text = "1"
         }
         
         // use regex for longer commands
         commands = findMovementCommands(str: words)
         if !commands.isEmpty {
         regexCommandText.text = "\(commands)"
         //runMovementCommands()
         commands = [] //reset commands array after it's done
         orderText.text = "2"
         }
         
         // use regex for short commands
         commands = findShortMovementCommands(str: words)
         regexCommandText.text = "\(commands)"
         if !commands.isEmpty {
         regexCommandText.text = "\(commands)"
         runShortMovementCommands()
         commands = [] //reset commands array after it's done
         orderText.text = "3"
         }
         */
        
        //loop through all words
        for str in strArr{
            
            // say "land" to make the drone land
            if str == "land" {
                land(fc)
            }
            //set boudary limit height and radius within 20m
            if str == "limit" {
                enableMaxFlightRadius(fc)
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
                    commands = ["go", "up"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
                if strArr[1] == "down" {
                    commands = ["go", "down"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
                if strArr[1] == "left" {
                    commands = ["go", "left"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
                if strArr[1] == "right" {
                    commands = ["go", "right"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
                if strArr[1] == "forward" {
                    commands = ["go", "forward"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
                if strArr[1] == "backward" {
                    commands = ["go", "backward"]
                    regexCommandText.text = "\(commands)"
                    runShortMovementCommands()
                    commands = [] //reset commands array after it's done
                    orderText.text = "1"
                }
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
                distanceText.text = String(describing: distance)
                orderText.text = "2"
                
                runLongCommands(dir: direction!, dist: distance!)
                regexCommandText.text = "\(commands)"
                commands = [] //reset commands array after it's done
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
            directionTest.text = "go left"
            commandCtrlData?.pitch = -1.0
        }
        if direction == "right" {
            commandCtrlData?.pitch = 1.0
            directionTest.text = "go right"
        }
        if direction == "up" {
            commandCtrlData?.verticalThrottle = 1.0
            directionTest.text = "go up"
        }
        if direction == "down" {
            commandCtrlData?.verticalThrottle = -1.0
            directionTest.text = "go down"
        }
        if direction == "forward" {
            commandCtrlData?.roll = 1.0
            directionTest.text = "go forward"
        }
        if direction == "backward"{
            commandCtrlData?.roll = -1.0
            directionTest.text = "go backward"
        }
        // enable Virtual Stick Mode which it disable function on remote control
        enterVirtualStickMode( newFlightCtrlData: commandCtrlData!)
        
    }
    
    
    func enterVirtualStickMode( newFlightCtrlData: DJIVirtualStickFlightControlData) {
        // x, y , z = forward, right, downward
        
        //cancel the missions just in case they are running
        //cancelMissionSaid()
        
        
        //aircraft = self.fetchAircraft()
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
                    if (self.fc?.isVirtualStickControlModeAvailable())! {
                        self.directionText.text = "Virtual stick control is available"
                        
                        
                        self.fc?.send(flightCtrlData, withCompletion: {(error: Error?) -> Void in
                            if error != nil {
                                self.VSMText.text = "could not send data: \(String(describing: error))"
                            }
                            else {
                                self.VSMText.text = "Data was sent"
                            }
                        })
                    }
                    else {
                        self.VSMText.text = "VSC mode is unavailable"
                    }
                    
                }
            })
        }
    }
    
    func runLongCommands(dir: String, dist: Double){
        //by here, we have each command being seperated into direction, distance, units
        // next steps are find location, distance and direction of drone
        
        // cancelMissionSaid()
        self.waypointMission.removeAllWaypoints()
        waypointMission = DJIMutableWaypointMission()
        
        
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
        
        //second way to get drone location
        /*
         guard let locationKey = DJIFlightControllerKey(param: DJIFlightControllerParamAircraftLocation) else {
         NSLog("Couldn't create the key")
         return
         }
         guard let keyManager = DJISDKManager.keyManager() else {
         print("Couldn't get the keyManager")
         // This will happen if not registered
         return
         }
         keyManager.startListeningForChanges(on: locationKey, withListener: self) { (oldValue, newValue) in
         if newValue != nil {
         location0 = newValue!.value as! CLLocation
         self.droneLocation = location0.coordinate
         }
         }
         */
        var lat: Double = droneLocation!.latitude
        var long: Double = droneLocation!.longitude
        
        //add first waypoint
        //let loc1 = CLLocationCoordinate2DMake((droneLocation?.latitude)! + myPointOffset, (droneLocation?.longitude)!)
        let loc1 = CLLocationCoordinate2DMake(lat, long)
        let waypoint: DJIWaypoint = DJIWaypoint(coordinate: loc1)
        waypoint.altitude = ALTITUDE
        self.waypointMission.add(waypoint)
        
        //if units are in meters
        //convert all unit to GPS coordinate points
        
        if dir == "east" || dir == "up"{
            long = long + convertMetersToPoint(m: dist)
        }
        if dir == "west" || dir == "down" {
            long = long - convertMetersToPoint(m: dist)
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
        positionText.text = "\(commLoc.latitude)"
        print("position now is " + String(describing: commLoc) )
        
        if CLLocationCoordinate2DIsValid(commLoc) {
            let waypoint2: DJIWaypoint = DJIWaypoint(coordinate: commLoc)
            waypoint2.altitude = ALTITUDE
            self.waypointMission.add(waypoint2)
        }
        
        //prepare mission
        prepareMission(missionName: self.waypointMission)
    }
    
    /*-----------if this doesn't work, try to call enterVirtualStickmode------------------------*/
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
    
    //when virtual stick mode is enabled, use are no longer able to use remote control
    func enableVirtualStickModeSaid() {
        //replace enableVirtualStickControlMode to setVirtualStickModeEnabled
        fc?.setVirtualStickModeEnabled(true, withCompletion: { (error: Error?) in
            if error != nil {
                self.VSMText.text = "virtual stick mode not enabled: \(String(describing: error))"
            }
            else {
                self.VSMText.text = "virtual stick mode enabled"
                //missing some codes
                //initalize a data object. They have pitch, roll, yaw, and throttle
                let commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                
                self.enterVirtualStickMode( newFlightCtrlData: commandCtrlData!)
                self.commandText.text = "\(String(describing: self.fc?.isVirtualStickControlModeAvailable()))"
                
            }
        })
    }
    
    //disable Virtual Stick Mode so you can use remote control
    func disableVirtualStickModeSaid() {
        //replace disableVirtualStickControlMode to setVirtualStickModeEnabled
        fc?.setVirtualStickModeEnabled(false, withCompletion: { (error: Error?) in
            
            if error != nil {
                self.VSMText.text = "virtual stick mode is not disabled: \(String(describing: error))"
            }
            else {
                self.VSMText.text = "virtual stick mode is disabled"
                //missing some codes
                
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
        var lat0:Double = 0.0
        //Earth’s radius, sphere
        let R:Double = 6378137.0
        //offset in meters
        let dn:Double = 100
        //Coordinate offsets in radians
        let pi:Double = Double.pi
        let dLat = dn/R

        lat0 = dLat*180/pi
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
    func setMaxFlightHeight(_ fc: DJIFlightController!) {
        //set maximum height is 20m
        fc.setMaxFlightHeight(20, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Height Error: \(error!.localizedDescription)")
            }
            
        })
    }
    func setMaxFlightRadius(_ fc: DJIFlightController!) {
        //set maximum height is 20m
        fc.setMaxFlightRadius(20, withCompletion: {[weak self](error: Error?) -> Void in
            if error != nil {
                self?.showAlertResult(info: "Max Radius Error: \(error!.localizedDescription)")
            }
            
        })
    }
    
    func enableMaxFlightRadius(_ fc: DJIFlightController!) {
        //set maximum height is 20m
        self.setMaxFlightHeight(fc)
        self.setMaxFlightRadius(fc)
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

