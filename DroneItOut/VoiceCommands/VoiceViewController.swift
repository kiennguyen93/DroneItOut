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
    
    func productConnected() {
        guard let newProduct = DJISDKManager.product() else {
            NSLog("Product is connected but DJISDKManager.product is nil -> something is wrong")
            return;
        }
    }
 
    @IBAction func loadRootView(_ sender: UIButton)
    {
        performSegue(withIdentifier: "VoiceToRootViewSegue", sender: Any?.self)
    }
    enum SKSState {
        case sksIdle
        case sksListening
        case sksProcessing
    }
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
    let mission = DJIMutableWaypointMission()
    
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
        print("begin recording")
    }
    func transactionDidFinishRecording(_ transaction: SKTransaction!) {
        state = .sksProcessing
        print("finished recording")
    }
    func transaction(_ transaction: SKTransaction!, didFinishWithSuggestion suggestion: String!) {
        state = .sksIdle
        sksTransaction = nil
        print("reset transaction")
        beginApp()
    }
    private func transaction(_ transaction: SKTransaction!, didFailWithError error: NSError!, suggestion: String!) {
        print("there is an error in processing speech transaction")
        state = .sksIdle
        sksTransaction = nil
        beginApp()
    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
    }


    // *************This is where the action happens after speech has been reconized!*********** //
    func transaction(_ transaction: SKTransaction!, didReceive recognition: SKRecognition!) {
        
        state = .sksIdle
        
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
        
        // make sure fc is flight controller
        var controlData = DJIVirtualStickFlightControlData()
        controlData.verticalThrottle = 2
        controlData.pitch = 0
        controlData.roll = 0
        controlData.yaw = 0
        
        fc = fetchFlightController()
        fc?.send(controlData, withCompletion: { (error) in
            if error != nil{
                let nserror = error! as NSError
                NSLog("Error controling virtual throttle \(String(describing: nserror))")
            }
        })
        if fc != nil{
            fc!.delegate = self
        }
        // use regex for NSEW compass direction
        self.commands = findNSEWCommands(str: words) //power on won't be in here
        if !commands.isEmpty {
            runNSEWDirectionCommands()
            commands = []
            orderText.text = "1"
        }
        
        // use regex for longer commands
        commands = findMovementCommands(str: words) //power on won't be in here
        if !commands.isEmpty {
            regexCommandText.text = "\(commands)"
            commands = []
            orderText.text = "2"
        }
        
        // use regex for short commands
        commands = findShortMovementCommands(str: words) //power on won't be in here
        regexCommandText.text = "\(commands)"
        if !commands.isEmpty {
            regexCommandText.text = "\(commands)"
            runShortMovementCommands()
            commands = []
            orderText.text = "3"
        }
        
        // if none of those regex are matched, it will go to a String
        var strArr = words.characters.split{$0 == " "}.map(String.init)
        print("strARR = \(strArr) ")
        if strArr.count > 1 {
            //take off
            if strArr[0] == "take" && strArr[1] == "off" {
                droneTakeOff(fc)
            }
            //say "power on" to start propellers
            if (strArr[0] == "power" && strArr[1] == "on") || strArr[0] == "on" {
                droneStartPropellers(fc)
            }
            //say "power off" to off propellers
            if (strArr[0] == "power" && strArr[1] == "off") || strArr[0] == "off"{
                droneStopPropellers(fc)
            }
        }
        
        //loop through words
        for str in strArr{
            //saying "connect" changes the text to verify the drone is connected
            if str == "connect" {
                if ConnectedProductManager.sharedInstance.connectedProduct != nil {
                    connectionStatus.text = "Connected"
                    connectionStatus.backgroundColor = UIColor.gray
                }
                else {
                    connectionStatus.text = "Disconnected"
                    connectionStatus.backgroundColor = UIColor.red
                }
            }
            
            
            // say "land" to make the drone land
            if str == "land" {
                droneLand(fc)
            }
            if str == "enable" {
                enableVirtualStickModeSaid()
            }
            if str == "disable" {
                disableVirtualStickModeSaid()
            }
            if str == "execute" {
                executeMission()
            }
            
            // say "cancel" to cancel mission
            if str == "cancel" {
                cancelMissionSaid()
                VSMText.text = "Mission cancelled"
            }
            if str == "pause" {
                pauseMissionSaid()
                VSMText.text = "Mission paused"
            }
            if str == "resume" {
                resumeMissionSaid()
                VSMText.text = "Mission resume"
            }
            
        }
    }
    
    //*********** REGEX METHOD **************//
    
    //use only for new compass commands
    func findNSEWCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(go|come|move|fly|head)\\s(north|south|east|west)\\s(to|by|for)?\\s?((?:\\d*\\.)?\\d+)?\\s(feet|foot|meters|meter|m|ft)?"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    //use for getting direction, distance, and units of measurements
    func findMovementCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(go|come|move|fly|head)\\s(right|left|up|down|forward|back)\\s(to|by|for)?\\s?((?:\\d*\\.)?\\d+)?\\s(feet|foot|meters|meter|m|ft)"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    //use for getting simple commands like "go left", "go right", "fly high"
    func findShortMovementCommands( str: String ) -> [String] {
        let commandRegex = "\\s*(drone|phantom|white)?\\s?(go|fly|move|head|come)\\s(left|right|up|down|forward|back|backward)"
        let matched = matches(for: commandRegex,in: str )
        print(matched)
        return matched
    }
    // matching function
    //use regex to extract matches from string and retrun array of strings
    func matches(for regex: String!, in text: String!) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    //******** RUN COMMANDS METHODS **********//
    func runShortMovementCommands() {
        var direction: String = ""
        if commands.count > 0 {
            for comm in commands {
                var commandArr = comm.characters.split{$0 == " "}.map(String.init)
                //var commandArr = comm.characters.split(separator: " ").map(String.init)
                if commandArr.count == 0 {
                    commandText.text = " "
                    directionText.text = " "
                }
                else {
                    commandText.text = "\(commandArr[0])"
                    directionText.text = "\(commandArr[1])"
                }
                
                if commands.count == 3 { //Drone goes left
                    direction = commandArr[2]
                }
                if commands.count == 2 { //Drone goes up
                    direction = commandArr[1]
                    distanceText.text = "\(direction)"
                }
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
                }
                if direction == "right" {
                    commandCtrlData?.pitch = 1.0
                }
                if direction == "up" {
                    commandCtrlData?.verticalThrottle = 1.0
                }
                if direction == "down" {
                    commandCtrlData?.verticalThrottle = -1.0
                }
                if direction == "forward" {
                    commandCtrlData?.roll = 1.0
                }
                if direction == "backward" || direction == "back" {
                    commandCtrlData?.roll = -1.0
                }
                
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
                    self.fc?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
                    
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
                prepareMission(missionName: self.waypointMission)
            }
        }
    }
    func enableVirtualStickModeSaid() {
        //replace enableVirtualStickControlMode to getVirtualStickModeEnabled
        
        fc?.getVirtualStickModeEnabled(completion: {(true, error: Error?)  ->Void in
            
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
    
    
    //********** missing some functions *****************//
    func disableVirtualStickModeSaid() {
        //replace disableVirtualStickControlMode to getVirtualStickModeEnabled
        fc?.getVirtualStickModeEnabled(completion: {(false, error: Error?)  ->Void in
            
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
        DJISDKManager.missionControl()?.pauseTimeline()
        
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
        return m*100
    }
    func prepareMission(missionName: DJIWaypointMission){
        print("Mission prepared!")
        executeMission()
    }
    
    //************ working drone methods *****************//
    func droneStartPropellers(_ fc: DJIFlightController!) {
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
    func droneTakeOff(_ fc: DJIFlightController!) {
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
    func droneLand(_ fc: DJIFlightController!) {
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
    func droneStopPropellers(_ fc: DJIFlightController!) {
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
            self.showAlertResult(info: "Component not existed")
        }
    }
    
}





