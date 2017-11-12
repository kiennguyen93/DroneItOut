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
import VideoPreviewer

class PredefinedPathViewController:  DJIBaseViewController, DJISDKManagerDelegate, SKTransactionDelegate, DJIFlightControllerDelegate, CLLocationManagerDelegate, DJICameraDelegate, DJIVideoFeedListener {
    // Does not break
    
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
    //Calculation 1m = GPS point - 0.000284
    let myPointOffset: Double = 0.0000181
    
    //SpeechKit variable
    var sksSession: SKSession?
    var sksTransaction: SKTransaction?
    var state = SKSState.sksIdle
    var SKSLanguage = "eng-USA"
    
    //DJI variable
    var connectionProduct: DJIBaseProduct? = nil
    var camera: DJICamera!
    var isRecording : Bool!
    @IBOutlet var recordTimeLabel: UILabel!
    
    @IBOutlet var captureButton: UIButton!
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet var recordModeSegmentControl: UISegmentedControl!
    @IBOutlet weak var videoView: UIView!
    
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
    var waypointMission = DJIMutableWaypointMission()
    var missionOperator: DJIWaypointMissionOperator? {
        return DJISDKManager.missionControl()?.waypointMissionOperator()
    }
    
    //label name for debugging
    @IBOutlet weak var directionText: UILabel!
    @IBOutlet weak var positionLatText: UILabel!
    @IBOutlet weak var positionLonText: UILabel!
    @IBOutlet weak var stateText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordTimeLabel.isHidden = true
        
        let voiceViewController = VoiceViewController()
        let djiRootViewController = DJIRootViewController()
        voiceViewController.dismiss(animated: true)
        djiRootViewController.dismiss(animated: true)
        //get current waypoint and put it into DJIMissionWaypoint
        firstWaypoint()
        
        // my nuance sandbox credentials
        let SKSAppKey = "e44c885455471dd09b1cef28fae758e80348e989db7b28e4b794a9608cfbfb714783c59dcae26d66fe5c8ef843e7e0462fc9cf0a44f7eefc8b985c18935789da";         //start a session
        let SKSAppId = "NMDPTRIAL_danieltn91_gmail_com20170911202728";
        let SKSServerHost = "sslsandbox-nmdp.nuancemobility.net";
        let SKSServerPort = "443";
        
        let SKSServerUrl = "nmsps://\(SKSAppId)@\(SKSServerHost):\(SKSServerPort)"
        
        // start nuance session with my account
        sksSession = SKSession(url: URL(string: SKSServerUrl), appToken: SKSAppKey)
        
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
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        VideoPreviewer.instance().setView(self.videoView)
        
        DJISDKManager.registerApp(with: self)
    }
    override func viewWillAppear(_ animated: Bool) {
        guard let connectedKey = DJIProductKey(param: DJIParamConnection) else {
            NSLog("Error creating the connectedKey")
            return;
        }
        super.viewWillDisappear(animated)
        VideoPreviewer.instance().setView(nil)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
        
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
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        VideoPreviewer.instance().setView(nil)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
        
    }
    override func viewDidDisappear(_ animated: Bool) {
        DJISDKManager.keyManager()?.stopAllListening(ofListeners: self)
        sksTransaction?.cancel()
        sksTransaction?.stopRecording()
        
        VideoPreviewer.instance().setView(self.videoView)
        DJISDKManager.registerApp(with: self)
    }
    func checkProductConnected() {
        //Display conneciton status
        if ConnectedProductManager.sharedInstance.product != nil {
            connectionStatus.text = "Connected"
            connectionStatus.textColor = UIColor.green
            
            camera = self.fetchCamera()
            if (camera != nil) {
                camera.delegate = self
                DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
            }
        }
        else {
            connectionStatus.text = "Disconnected"
            connectionStatus.textColor = UIColor.red
            //clear video data
            camera = nil
            VideoPreviewer.instance().clearVideoData()
            VideoPreviewer.instance().close()
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
        DJISDKManager.startConnectionToProduct()
        DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
        VideoPreviewer.instance().start()
        
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
    @IBAction func loadRootView(_ sender: UIButton)
    {
        performSegue(withIdentifier: "PathsToRootSegue", sender: Any?.self)
    }
    @IBAction func loadVoiceView(_ sender: UIButton)
    {
        performSegue(withIdentifier: "PathsToVoiceSegue", sender: Any?.self)
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
        state = .sksIdle
        stateText.text = "Idle"
        
        if strArr[0] == "ride" {
            strArr[0] = "right"
        }
        if strArr[0] == "stock" {
            strArr[0] = "start"
        }
        if strArr.count == 2 || strArr.count == 3{
            
            switch strArr[1] {
            case "one":
                strArr[1] = "1"
            case "two":
                strArr[1] = "2"
            case "to":
                strArr[1] = "2"
            case "three":
                strArr[1] = "3"
            case "four":
                strArr[1] = "4"
            case "five":
                strArr[1] = "5"
            case "six":
                strArr[1] = "6"
            case "seven":
                strArr[1] = "7"
            case "eight":
                strArr[1] = "8"
            case "nine":
                strArr[1] = "9"
            case "ten":
                strArr[1] = "10"
            default:
                break
            }
        }
        
        
        
        let joinwords = strArr.joined(separator: " ")
        recognitionText.text = joinwords
        print("recognition recieved: \(recognition.text)")
        print("state: \(state)")
        
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
            if str == "execute" || str == "start" {
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
            //say "remove to remove all listeners
            if str == "remove" {
                missionOperator?.removeAllListeners()
            }
            if str == "again" {
                
            }
            //say "back" to back to VoiceViewController
            if str == "homepage" {
                let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DJIRootViewController")
                UIApplication.topViewController()?.present(newViewController, animated: true, completion: nil)
            }
            
        }
        if strArr.count > 1{
            //take off
            if strArr[0] == "take" && strArr[1] == "off" {
                takeOff(fc)
            }
                //set boudary limit height and radius within 20m
            else if strArr[0] == "limit" && isNumber(stringToTest: strArr[1]) == true{
                enableMaxFlightRadius(fc,dist: strArr[1])
            }
            else if (strArr[0] == "up" || strArr[0] == "down" || strArr[0] == "left" || strArr[0] == "right") && self.isStringAnDouble(string: strArr[1]) {
                direction = strArr[0]
                distance = Double(strArr[1])
                
                //set to label
                directionText.text = direction
                runLongCommands(dir: direction!, dist: distance!)
            }
            else if (strArr[0] == "voice" && (strArr[1] == "commands" || strArr[1] == "commands")){
                let newViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VoiceViewController")
                UIApplication.topViewController()?.present(newViewController, animated: true, completion: nil)
            }
            else {
                self.showAlertResult(info: "Command not found, say your next command!")
            }
        }
        
    }
    func isStringAnDouble(string: String) -> Bool {
        return Double(string) != nil
    }
    var lat: Double = 0.0
    var long: Double = 0.0
    //******** RUN COMMANDS METHODS **********//
    
    func firstWaypoint(){
        disableVirtualStickModeSaid()
        // cancelMissionSaid()
        self.waypointMission.removeAllWaypoints()
        waypointMission = DJIMutableWaypointMission()
        
        // 5 mission paramenter always needed
        waypointMission.maxFlightSpeed = 2
        waypointMission.autoFlightSpeed = 1
        waypointMission.headingMode = .auto
        waypointMission.rotateGimbalPitch = true
        waypointMission.flightPathMode = .normal
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
        
        //set drone locatoin to a gobal variable to use it later
        droneFirstLocation = droneLocation0
        
        let droneLocation = droneLocation0.coordinate
        
        lat = droneLocation.latitude
        long = droneLocation.longitude
        
        waypointMission.pointOfInterest = droneLocation
        
        let loc1 = CLLocationCoordinate2DMake(lat, long)
        let currentWaypoint = DJIWaypoint(coordinate: loc1)
        ALTITUDE = Float(droneLocation0.altitude)
        currentWaypoint.altitude = ALTITUDE
        currentWaypoint.heading = 0
        currentWaypoint.actionTimeoutInSeconds = 60
        currentWaypoint.cornerRadiusInMeters = 5
        //currentWaypoint.turnMode = .clockwise
        currentWaypoint.gimbalPitch = 0
        
        //add waypoints to mission
        waypointMission.add(currentWaypoint)
    }
    var droneFirstLocation: CLLocation?
    
    func runLongCommands(dir: String, dist: Double){
        disableVirtualStickModeSaid()
        if dir == "up"{
            //long = long + convertMetersToPoint(m: dist)
            ALTITUDE = Float((droneFirstLocation?.altitude)!) + Float(dist)
        }
        if dir == "down" {
            //long = long - convertMetersToPoint(m: dist)
            ALTITUDE = Float((droneFirstLocation?.altitude)!) - Float(dist)
        }
        if dir == "right"{
            lat = lat + convertMetersToPointLat(m: dist)
        }
        if dir == "left"{
            lat = lat - convertMetersToPointLat(m: dist)
        }
        //add second waypoint
        let loc2 = CLLocationCoordinate2DMake(lat, long)
        let wpoint2 = DJIWaypoint(coordinate: loc2)
        wpoint2.altitude = ALTITUDE
        wpoint2.heading = 0
        wpoint2.actionTimeoutInSeconds = 60
        wpoint2.cornerRadiusInMeters = 5
        //wpoint2.turnMode = .clockwise
        wpoint2.gimbalPitch = 0
        
        //add waypoint to Mission
        waypointMission.add(wpoint2)
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
    var currentMissionState: DJIWaypointMissionState?
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
        if currentMissionState == DJIWaypointMissionState.executing || currentMissionState == DJIWaypointMissionState.executionPaused{
            missionOperator?.stopMission(completion: { (error: Error?) in
                if error != nil {
                    self.showAlertResult(info: "Error stop mission " + (error?.localizedDescription)!)
                }
                else {
                    self.showAlertResult(info: "Mission stoped sucessfully!")
                    self.waypointMission.removeAllWaypoints()
                }
            })
        }
        
    }
    func resumeMissionSaid(){
        if currentMissionState == DJIWaypointMissionState.executionPaused{
            missionOperator?.resumeMission(completion: { (error: Error?) in
                if error != nil {
                    self.showAlertResult(info: "Error resume mission " + (error?.localizedDescription)!)
                }
                else {
                    self.showAlertResult(info: "Mission resume sucessfully!")
                }
            })
        }
    }
    func executeMission(){
        //prepareMission before execute
        prepareMission(missionName: waypointMission)
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
                currentMissionState = DJIWaypointMissionState.readyToExecute
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
                currentMissionState = DJIWaypointMissionState.executing
                missionOperator?.removeAllListeners()
            }
        }
        missionOperator?.load(missionName)
        // Upload the mission and then execute it
        missionOperator?.addListener(toUploadEvent: self, with: DispatchQueue.main, andBlock: {(event) in
            if event.error != nil {
                self.showAlertResult(info: "There was an error trying to upload the mission, trying again")
                print("There was an error trying to upload the mission, trying again")
                self.currentMissionState = DJIWaypointMissionState.readyToUpload
                self.missionOperator?.uploadMission(completion: didMissionUpload)
            }
            else {
                self.showAlertResult(info:"Mission was uploaded, Starting mission")
                print("Mission was uploaded, Starting mission")
                // start mission
                self.currentMissionState = DJIWaypointMissionState.readyToExecute
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
    
    /* ===========================Video Recording Part =================================*/
    override func fetchCamera() -> DJICamera? {
        let product = DJISDKManager.product()
        
        if (product == nil) {
            return nil
        }
        
        if (product!.isKind(of: DJIAircraft.self)) {
            return (product as! DJIAircraft).camera
        } else if (product!.isKind(of: DJIHandheld.self)) {
            return (product as! DJIHandheld).camera
        }
        
        return nil
    }
    
    func formatSeconds(seconds: UInt) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        
        return(dateFormatter.string(from: date))
    }
    
    //
    //  DJIBaseProductDelegate
    //
    
    func productConnected(_ product: DJIBaseProduct?) {
        
        NSLog("Product Connected")
        
        
        if (product != nil) {
            product!.delegate = self
            
            camera = self.fetchCamera()
            
            if (camera != nil) {
                camera!.delegate = self
                
                VideoPreviewer.instance().start()
                
            }
        }
    }
    
    func productDisconnected() {
        NSLog("Product Disconnected")
        
        camera = nil
        VideoPreviewer.instance().clearVideoData()
        VideoPreviewer.instance().close()
        
    }
    
    
    //
    //  DJICameraDelegate
    //
    
    func camera(_ camera: DJICamera, didUpdate cameraState: DJICameraSystemState) {
        self.isRecording = cameraState.isRecording
        self.recordTimeLabel.isHidden = !self.isRecording
        
        self.recordTimeLabel.text = formatSeconds(seconds: cameraState.currentVideoRecordingTimeInSeconds)
        
        if (self.isRecording == true) {
            self.recordButton.setTitle("Stop Record", for: UIControlState.normal)
        } else {
            self.recordButton.setTitle("Start Record", for: UIControlState.normal)
        }
        
        if (cameraState.mode == DJICameraMode.shootPhoto) {
            self.recordModeSegmentControl.selectedSegmentIndex = 0
        } else {
            self.recordModeSegmentControl.selectedSegmentIndex = 1
        }
        
    }
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData rawData: Data) {
        let videoData = rawData as NSData
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: videoData.length)
        
        videoData.getBytes(videoBuffer, length: videoData.length)
        
        
        VideoPreviewer.instance().push(videoBuffer, length: Int32(videoData.length))
    }
    //
    //  IBAction Methods
    //
    
    @IBAction func captureAction(_ sender: UIButton) {
        
        if (camera != nil) {
            camera.setMode(DJICameraMode.shootPhoto, withCompletion: { (error) in
                
                if (error != nil) {
                    NSLog("Set Photo Mode Error: " + String(describing: error))
                }
                
                self.camera.startShootPhoto(completion: { (error) in
                    if (error != nil) {
                        NSLog("Shoot Photo Mode Error: " + String(describing: error))
                    }
                })
            })
        }
    }
    
    @IBAction func recordAction(_ sender: UIButton) {
        
        if (camera != nil) {
            if (self.isRecording) {
                camera.stopRecordVideo(completion: { (error) in
                    if (error != nil) {
                        NSLog("Stop Record Video Error: " + String(describing: error))
                    }
                })
            } else {
                camera.setMode(DJICameraMode.recordVideo,  withCompletion: { (error) in
                    
                    self.camera.startRecordVideo(completion: { (error) in
                        if (error != nil) {
                            NSLog("Stop Record Video Error: " + String(describing: error))
                        }
                    })
                })
            }
        }
    }
    
    
    @IBAction func recordModeSegmentChange(_ sender: UISegmentedControl) {
        
        if (camera != nil) {
            if (sender.selectedSegmentIndex == 0) {
                camera.setMode(DJICameraMode.shootPhoto,  withCompletion: { (error) in
                    
                })
                
            } else if (sender.selectedSegmentIndex == 1) {
                camera.setMode(DJICameraMode.recordVideo,  withCompletion: { (error) in
                    
                })
                
                
            }
        }
    }
}

