//
//  GameScene.swift
//  DroneItOut
//
//  Created by Daniel Nguyen on 9/7/17.
//  Copyright © 2017 DJI. All rights reserved.
//
import UIKit
import SpriteKit
import SpeechKit

var backgroundColorCustom = UIColor.white

class GameScene: SKScene, SKTransactionDelegate {
    
    var session: SKSession?
    var transaction: SKTransaction?
    
    var Drone = SKSpriteNode()
    var myLabel: SKLabelNode!
    var TextureAtlas = SKTextureAtlas()
    var TextureArray = [SKTexture]()
    var flightWobble = [SKAction]()
    
    override func didMove(to view: SKView) {
        
        //set background
        self.backgroundColor = UIColor.white
        
        
        TextureAtlas = SKTextureAtlas(named: "droneflight")
        
        NSLog("\(TextureAtlas.textureNames)")
       
        //adding animation images to texture array
        TextureArray.append(SKTexture(imageNamed: "2drone.png"))
        TextureArray.append(SKTexture(imageNamed: "3drone.png"))
        TextureArray.append(SKTexture(imageNamed: "4drone.png"))
        TextureArray.append(SKTexture(imageNamed: "1drone.png"))
        
        myLabel = SKLabelNode(fontNamed: "Arial")
        myLabel.text = "power off"
        myLabel.fontSize = 20
        myLabel.position = CGPoint(x: self.size.width / 2, y: 50)
        myLabel.fontColor = UIColor.black
        
        self.addChild(myLabel)
        
        
        /*
        flightWobble.append(SKAction.moveBy(x: 15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: -15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: -15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: 15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: 15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: -15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: -15, y: 0, duration: 3))
        flightWobble.append(SKAction.moveBy(x: 15, y: 0, duration: 3))
        */
        
        
        flightWobble.append(SKAction.move(by: CGVector(dx: 15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: -15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: -15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: 15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: 15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: -15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: -15, dy: 0), duration: 3))
        flightWobble.append(SKAction.move(by: CGVector(dx: 15, dy: 0), duration: 3))
        
        
        //positioning drone animation and adding child node to the view
        Drone = SKSpriteNode(imageNamed: TextureAtlas.textureNames[1])
        Drone.size = CGSize(width: 330, height: 355)
        Drone.position = CGPoint(x: self.size.width / 2, y: 150 )
        self.addChild(Drone)
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { //neeed to have developer sandbox credentials to
        let SKSAppKey = "e44c885455471dd09b1cef28fae758e80348e989db7b28e4b794a9608cfbfb714783c59dcae26d66fe5c8ef843e7e0462fc9cf0a44f7eefc8b985c18935789da";         //start a session
        let SKSAppId = "NMDPTRIAL_danieltn91_gmail_com20170911202728";
        let SKSServerHost = "sslsandbox-nmdp.nuancemobility.net";
        let SKSServerPort = "443";
        let SKSLanguage = "eng-USA";
        let SKSServerUrl = "nmsps://\(SKSAppId)@\(SKSServerHost):\(SKSServerPort)"
   
        let sessions = SKSession(url: NSURL(string: SKSServerUrl)! as URL, appToken: SKSAppKey)
        
       
        transaction = sessions!.recognize(withType: SKTransactionSpeechTypeDictation,detection: .short, language: SKSLanguage, delegate: self)
    }
    
    // nuance server responses to commands
    func transaction(_ transaction: SKTransaction!, didReceive recognition: SKRecognition!) {
        
        myLabel.text = recognition.text.lowercased()
        
        let words = recognition.text.lowercased()
        print("You said : \(words)")
        
        var strArr = words.characters.split{$0 == " "}.map(String.init)
        
        var distance: CGFloat = 0
        var direction: String = " "
        var goCalled: Bool = false
        var inFlight: Bool = false
        
        //set up animation actions that can be run using a key to activate/deactivate them
        let land: SKAction = SKAction.move(to: CGPoint(x: self.size.width / 2, y: 150 ), duration: 2.0 )
        let propellers: SKAction = SKAction.repeatForever(SKAction.animate(with: TextureArray, timePerFrame: 0.05))
        
        let wobble: SKAction = SKAction.sequence(flightWobble)
        
        //start the propellers
        if strArr[0] == "power"{
            if strArr[1] == "on" {
                Drone.isPaused = false
                Drone.run(propellers, withKey: "action1")
                print("Drone: power on")
                
            }
            if strArr[1] == "off" {
                Drone.isPaused = true
                Drone.removeAction(forKey: "action1")
                Drone.texture = SKTexture(imageNamed: "2drone.png")
                print("Drone: power off")
            }
        }

        // for simple flight commands
        for str in strArr{
            if str == "land" {
                inFlight = false
                Drone.run(land)
                Drone.removeAction(forKey: "wobbleAction")
                print("Drone: Land")
            }
            // go command
            if str == "go" {
                goCalled = true
                inFlight = true
            }
            //get distance from array
            if let number = Int(str){
                distance = CGFloat(number)
                print("distance = " + String(describing: distance))
            }
            //get direction from array
            if str == "up" {
                direction = str
                print("direction = " + direction)
            }
            if str == "down" {
                direction = str
                print("direction = " + direction)
            }
            //change background
            if str == "change" {
                Drone.size.width += 100
                Drone.size.height += 100
                backgroundColor = UIColor(red: 0.6863, green: 0, blue: 0.0431, alpha: 1.0) /* #af000b */
                myLabel.fontColor = UIColor.white
            }
            //turn it back to normal
            if str == "normal" {
                Drone.size.width -= 100
                Drone.size.height -= 100
                backgroundColor = UIColor.white
                myLabel.fontColor = UIColor.black
            }
            if str == "off"{
                Drone.isPaused = true
                Drone.removeAction(forKey: "action1")
                Drone.texture = SKTexture(imageNamed: "2drone.png")
                print("Drone: power off")
            }
        }
        if goCalled {
            
            let upSequence: SKAction = SKAction.moveBy(x: 0, y: distance * 10, duration: 1.2 )
            let downSequence: SKAction = SKAction.moveBy(x: 0, y: -(distance * 10), duration: 1.2)
            
            if direction == "up" {
                Drone.run(upSequence)
            }
            if direction == "down" {
                Drone.run(downSequence)
            }
        }
        //if drone is in flight, run the wobble animation sequence
        if inFlight{
            Drone.run(wobble, withKey: "wobbleAction")
        }
    }
    
    
    
}

