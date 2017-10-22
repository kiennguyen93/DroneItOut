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
    var instanceOfDJIRootViewControllert: DJIRootViewController = DJIRootViewController()
    //instanceOfDJIRootViewControllert.someMethod()
    
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
    
    
    //SpeechKit variable
    var sksSession: SKSession?
    var sksTransaction: SKTransaction?
    var state = SKSState.sksIdle
    var SKSLanguage = "eng-USA"
    
    //DJI variable
    var appkey = "b268f50a003c96ab9fb53846"
    var connectionProduct: DJIBaseProduct? = nil
    
    //flight Controller
    var fc: DJIFlightController?
    var delegate: DJIFlightControllerDelegate?
    var aircraftLocation: CLLocationCoordinate2D? = nil
    
    //change DJIFlightControllerCurrentState to DJIFlightControllerState
    var currentState: DJIFlightControllerState? = nil
    var aircraft: DJIAircraft? = nil
    
    //mission variable
    var missionManager: DJIMissionControl?
    
    var hotpointMission: DJIHotpointMission = DJIHotpointMission()
    var mCurrentHotPointCoordinate: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var locs: [CLLocationCoordinate2D] = []
    var uploadStatus: Float = 0
    var commands: [String] = []
    var speed: Double = 0
    
    //store coordinate that uses to create waypoint mission
    var waypointList: [DJIWaypoint] = []
    
    var waypointMission: DJIWaypointMission = DJIMutableWaypointMission()
    var mission = DJIMutableWaypointMission()
    
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
        
        let aircraft: DJIAircraft? = self.fetchAircraft()
        if aircraft != nil {
            aircraft!.delegate = self
            aircraft!.flightController?.delegate = self
        }
        
        missionStatusBar.setProgress(0, animated: true)
        
        //beign listening to user and this gets called repeatedly to ensure countinue listening
        beginApp()
        
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
        recognitionText.text = recognition.text.lowercased()
        print("recognition recieved: \(recognition.text)")
        print("state: \(state)")
        
        
        //make an array of word said
        var words = recognition.text.lowercased()
        
        //nuance catches 1 as "one", so we need to change it
        if #available(iOS 9.0, *) {
            if words.localizedStandardRange(of: "one") != nil {
                words = words.replacingOccurrences(of: "one", with: "1")
            }
        } else {
            // Fallback on earlier versions
        }
        
        // set and ensure fc is flight controller
        fc = fetchFlightController()
        if fc != nil{
            fc!.delegate = self
        }
        
        // use regex for NSEW compass direction
        self.commands = findNSEWCommands(str: words)
        if !commands.isEmpty {
            runNSEWDirectionCommands()
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
        
        // if none of those regex are matched, it will go to a String
        var strArr = words.characters.split{$0 == " "}.map(String.init)
        
        if strArr.count > 1 {
            
            
            //take off
            if strArr[0] == "take" && strArr[1] == "off" {
                takeOff(fc)
            }
                /*
                 else if strArr[0] == "go" && strArr[1] == "up" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 else if strArr[0] == "go" && strArr[1] == "down" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 else if strArr[0] == "go" && strArr[1] == "left" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 else if strArr[0] == "go" && strArr[1] == "right" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 else if strArr[0] == "go" && strArr[1] == "backward" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 else if strArr[0] == "go" && strArr[1] == "forward" {
                 runShortMovementCommands(direction: strArr[1])
                 }
                 */
            else if (strArr[0] == "power" && strArr[1] == "on") || strArr[0] == "on" {
                self.showAlertResult(info: "Power on function is not existed. Please say your next command !")
                // startPropellers(fc)
            }
                //say "power off" to off propellers
                //to ensure safety, this function will use auto land fuction to land the aircraft before turn off propellers
            else if (strArr[0] == "power" && strArr[1] == "off") || strArr[0] == "off"{
                stopPropellers(fc)
            }
                // say "goHome" to make the drone land
            else if strArr[0] == "go" && strArr[1] == "home"{
                goHome(fc)
            }
            else {
                showAlertResult(info: "This command is not in the system, please say your next command !")
                strArr.removeAll()
            }
            
        }
        
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
                cancelMissionSaid()
                VSMText.text = "Mission cancelled"
            }
            // say "stop" to stop mission
            if str == "stop" {
                pauseMissionSaid()
                VSMText.text = "Mission paused"
            }
            // say "resume" to resume mission
            if str == "resume" {
                resumeMissionSaid()
                VSMText.text = "Mission resume"
            }
            
            
            
        }
    }
    
    //*********** REGEX METHOD **************//
    
    //use only for new compass commands
    func findNSEWCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(go)\\s(north|south|east|west)?\\s?((?:\\d*\\.)?\\d+)?\\s(feet|foot|meters|meter|m|ft)?"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    //use for getting direction, distance, and units of measurements
    func findMovementCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(go)\\s(left|right|up|down|forward|backward)?\\s?((?:\\d*\\.)?\\d+)?\\s(feet|foot|meters|meter|m|ft)"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    //use for getting simple commands like "go left", "go right"
    func findShortMovementCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(go)\\s(left|right|up|down|forward|backward)"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    // matching function
    //use regex to extract matches from string and retrun array of strings
    func matches(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            //transform to all strings and return
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    //******** RUN COMMANDS METHODS **********//
    func runShortMovementCommands() {
        var direction: String = ""
        print("Short commands: \(commands)")
        if commands.count > 0 {
            for comm in commands {
                var commandArr = comm.characters.split{$0 == " "}.map(String.init)
                commandText.text = "\(commandArr[0])"
                directionText.text = "\(commandArr[1])"
                
                
                
                if commandArr.count == 2 { //Go up
                    direction = commandArr[1]
                    distanceText.text = "\(direction)"
                }
                /*
                 if commandArr.count == 3 { //Drone goes left
                 direction = commandArr[2]
                 }
                 */
                //initalize a data object. They have pitch, roll, yaw, and throttle
                var commandCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                //flightCtrlData?.pitch = 0.5 - make it goes to the right a little bit 0.5m/s
                //Here is where data gets changed
                commandCtrlData?.pitch = 0
                commandCtrlData?.roll = 0
                commandCtrlData?.yaw = 0
                commandCtrlData?.verticalThrottle = 0
                
                if direction == "left" {
                    commandCtrlData?.pitch = -1.0
                    directionTest.text = "test: go left"
                    
                }
                if direction == "right" {
                    commandCtrlData?.pitch = 1.0
                    directionTest.text = "test: go right"
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
                }
                // enable Virtual Stick Mode which it disable function on remote control
                enterVirtualStickMode( newFlightCtrlData: commandCtrlData!)
            }
        }
    }
    
    func enterVirtualStickMode( newFlightCtrlData: DJIVirtualStickFlightControlData) {
        // x, y , z = forward, right, downward
        
        //cancel the missions just in case they are running
        cancelMissionSaid()
        
        aircraft = self.fetchAircraft()
        fc = self.fetchFlightController()
        fc?.delegate = self
        if fc != nil {
            //must first enable virtual control stick mode
            //fc?.enableVirtualStickControlMode(completion: {(error: Error?) ->Void in
            //replace enableVirtualStickControlMode to getVirtualStickModeEnabled
            fc?.getVirtualStickModeEnabled(completion: {(true, error: Error?)  ->Void in
                
                if error != nil {
                    self.VSMText.text = "virtual stick mode is not enabled: \(String(describing: error))"
                }
                else {
                    self.VSMText.text = "virtual stick mode enabled"
                    
                    self.fc?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                    self.fc?.rollPitchControlMode = DJIVirtualStickRollPitchControlMode.velocity
                    self.fc?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
                    
                    //DJIVirtualStickFlightCoordinateSystem.body doesn't work anymore
                    self.fc?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.ground
                    //self.fc?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
                    
                    var flightCtrlData: DJIVirtualStickFlightControlData? = DJIVirtualStickFlightControlData.init()
                    
                    //Here is where the data gets changed
                    flightCtrlData?.pitch = newFlightCtrlData.pitch
                    flightCtrlData?.roll = newFlightCtrlData.roll
                    flightCtrlData?.yaw = newFlightCtrlData.yaw
                    flightCtrlData?.verticalThrottle = newFlightCtrlData.verticalThrottle
                    
                    self.commandText.text = "\(String(describing: self.fc?.isVirtualStickControlModeAvailable()))"
                    
                    //if VirtualStickControlMode is available, the data will be sent and drone will perfom command
                    if (self.fc?.isVirtualStickControlModeAvailable())! {
                        self.directionText.text = "Virtual stick control is available"
                        
                        self.fc?.send(flightCtrlData!, withCompletion: {(error: Error?) -> Void in
                            if error != nil {
                                self.VSMText.text = "could not send data: \(String(describing: error))"
                            }
                            else {
                                self.VSMText.text = "Data was sent"
                            }
                        })
                    }
                    else {
                        self.VSMText.text = "Virtual stick control mode is unavailable"
                    }
                }
            })
        }
    }
    func runNSEWDirectionCommands(){
        //if the recongnition text matchesthe NSEW regex,then this method will execute
        if commands.count > 0 {
            for comm in commands {
                var dist: String
                var direction: String
                var units: String
                
                var commandArr = comm.characters.split{$0 == " "}.map(String.init)
                
                direction = commandArr[1]
                
                if commandArr[2] == "by" {
                    if commandArr[3] == "to" { commandArr[3] = "2" }
                    if commandArr[3] == "to0" { commandArr[3] = "2" }
                    distanceText.text = "\(commandArr[3])"
                    dist = commandArr[3]
                    unitText.text = "\(commandArr[4])"
                    units = commandArr[4]
                }
                else if commandArr[2] == "for" {
                    if commandArr[3] == "to" { commandArr[3] = "2"}
                    if commandArr[3] == "too" { commandArr[3] = "2"}
                    distanceText.text = "\(commandArr[3])"
                    dist = commandArr[3]
                    unitText.text = "\(commandArr[4])"
                    units = commandArr[4]
                    
                } else {
                    if commandArr[3] == "to" { commandArr[3] = "2"}
                    if commandArr[3] == "too" { commandArr[3] = "2"}
                    distanceText.text = "\(commandArr[3])"
                    dist = commandArr[3]
                    unitText.text = "\(commandArr[4])"
                    units = commandArr[4]
                }
                let distance: Double = Double(dist)!
                //by here, we have each command being seperated into direction, distance, units
                // next steps are find location, distance and direction of drone
                
                //cancel the current mission and remove all waypoints form waypoint list
                cancelMissionSaid()
                self.mission.removeAllWaypoints()
                
                //get drone's location
                var droneLocation: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0)
                
                if ((self.currentState != nil) && CLLocationCoordinate2DIsValid(aircraftLocation!)){
                    
                    //droneLocation = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    droneLocation = aircraftLocation!
                    
                    //my conversion CLLocationCoordinate2DIsValid to CLLocation
                    /*
                     var getLat: CLLocationDegrees = droneLocation.latitude
                     var getLon: CLLocationDegrees = droneLocation.longitude
                     var center: CLLocation =  CLLocation(latitude: getLat, longitude: getLon)
                     */
                    
                    //finding GPS location
                    let waypoint: DJIWaypoint = DJIWaypoint(coordinate: droneLocation)
                    waypoint.altitude = ALTITUDE
                    
                    self.mission.add(waypoint)
                }
                var lat: Double = droneLocation.latitude
                var long: Double = droneLocation.longitude
                
                var commLoc: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0)
                
                //if units are in meters
                //convert all unit to GPS coordinate points
                if units == "m" || units == "meter" || units == "meters" {
                    if direction == "east" {
                        long = long + convertMetersToPoint(m: distance)
                    }
                    if direction == "west" {
                        long = long + convertMetersToPoint(m: distance)
                    }
                    if direction == "noth" {
                        lat = lat + convertMetersToPoint(m: distance)
                    }
                    if direction == "south" {
                        lat = lat + convertMetersToPoint(m: distance)
                    }
                }
                // if units are in feet
                if units == "ft" || units == "feet" || units == "foot" {
                    if direction == "east" {
                        long = long + convertMetersToPoint(m: distance)
                    }
                    if direction == "west" {
                        long = long + convertMetersToPoint(m: distance)
                    }
                    if direction == "noth" {
                        lat = lat + convertMetersToPoint(m: distance)
                    }
                    if direction == "south" {
                        lat = lat + convertMetersToPoint(m: distance)
                    }
                }
                commLoc.latitude = lat
                commLoc.longitude = long
                positionText.text = "\(commLoc.latitude)"
                
                if CLLocationCoordinate2DIsValid(commLoc) {
                    let commWayPoint: DJIWaypoint = DJIWaypoint(coordinate: commLoc)
                    commWayPoint.altitude = ALTITUDE
                    self.mission.add(commWayPoint)
                }
                
                // 5 mission paramenter always needed
                self.mission.maxFlightSpeed = 2
                self.mission.autoFlightSpeed = 1
                self.mission.headingMode = DJIWaypointMissionHeadingMode.auto
                self.mission.flightPathMode = DJIWaypointMissionFlightPathMode.curved
                mission.finishedAction = DJIWaypointMissionFinishedAction.noAction
                
                //prepare mission
                prepareMission(missionName: self.mission)
            }
        }
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
    fileprivate var started = false
    fileprivate var paused = false
    
    func cancelMissionSaid() {
        //need to define DJIWaypointMissionOperator
        //var oper: DJIWaypointMissionOperator
        
        
        print("Mission Cancelled !")
        DJISDKManager.missionControl()?.stopTimeline()
    }
    func pauseMissionSaid(){
        print("Mission paused !")
        DJISDKManager.missionControl()?.stopTimeline()
        // DJISDKManager.missionControl()?.pauseTimeline()
        
    }
    func resumeMissionSaid(){
        print("Mission resume !")
        DJISDKManager.missionControl()?.resumeTimeline()
    }
    func executeMission(){
        print("Mission executed !")
        if self.paused {
            DJISDKManager.missionControl()?.resumeTimeline()
        } else if self.started {
            DJISDKManager.missionControl()?.pauseTimeline()
        } else {
            DJISDKManager.missionControl()?.startTimeline()
        }
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
    func prepareMission(missionName: DJIWaypointMission){
        print("Mission prepared!")
        //executeMission()
        // Upload the mission and then execute it
        // Setting up the mission manager
        /*
         mission = DJIWaypointMission
         self.mission.(mission, withProgress: nil, withCompletion:
         {[weak self] (error: NSError?) -> Void in
         if error == nil {
         self?.missionManager!.startMissionExecutionWithCompletion({ [weak self] (error: NSError?) -> Void in
         if error != nil {
         print("Error starting mission" + "abcd")
         self!.logDebug("Error starting mission: " + (error?.description)!)
         
         }
         })
         } else {
         print("Error preparing mission")
         self!.logDebug("Error preparing mission: " + (error?.description)!)
         }
         
         })
         */
    }
    
    //************ Flight Controller Drone Method *****************//
    //DJI took away turnOnMotors, they may open it for the next comming version
    //so we can just call takeoff
    /*
     func startPropellers(_ fc: DJIFlightController!) {
     print("fc = \(fc)")
     if fc != nil {
     fc!.turnOnMotors(completion: {[weak self](error: Error?) -> Void in
     if error != nil {
     self?.showAlertResult(info: "TurnOn Error: \(error!.localizedDescription)")
     }
     else {
     self?.showAlertResult(info: "Turnon Succeeded.")
     }
     })
     }
     else {
     self.showAlertResult(info: "Start Propellers Component not existed")
     }
     }
     */
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
    
    
}
