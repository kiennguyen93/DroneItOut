//
//  DJIWaypointConfigViewController.m
//  DroneItOut
//
//  Created by Kien Nguyen on 9/6/2017.
//  Copyright (c) 2017 Kien Nguyen. All rights reserved.
//


#import "DJIWaypointConfigViewController.h"

@interface DJIWaypointConfigViewController ()

@end

@implementation DJIWaypointConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initUI];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initUI
{
    self.altitudeTextField.text = @"20"; //Set the altitude to 20
    self.autoFlightSpeedTextField.text = @"8"; //Set the autoFlightSpeed to 8
    self.maxFlightSpeedTextField.text = @"10"; //Set the maxFlightSpeed to 10
    [self.actionSegmentedControl setSelectedSegmentIndex:1]; //Set the finishAction to DJIWaypointMissionFinishedGoHome
    [self.headingSegmentedControl setSelectedSegmentIndex:0]; //Set the headingMode to DJIWaypointMissionHeadingAuto
    
}
//The CANCEL button to cancel the waypoint mission
- (IBAction)cancelBtnAction:(id)sender {
 
    if ([_delegate respondsToSelector:@selector(cancelBtnActionInDJIWaypointConfigViewController:)]) {
        [_delegate cancelBtnActionInDJIWaypointConfigViewController:self];
    }
}
//The FINISH button to upload the mission to the drone
- (IBAction)finishBtnAction:(id)sender {
    
    if ([_delegate respondsToSelector:@selector(finishBtnActionInDJIWaypointConfigViewController:)]) {
        [_delegate finishBtnActionInDJIWaypointConfigViewController:self];
    }
    
}

//The ALTITUDE edit button
- (IBAction)altitudeDismiss:(id)sender {
    [altitude resignFirstResponder];
}
//The SPEED edit button
- (IBAction)autoFlightSpeedDismiss:(id)sender {
     [autoFlightSpeed resignFirstResponder];
}
//The MAX SPEED edit button
- (IBAction)maxSpeedDismiss:(id)sender {
     [maxSpeed resignFirstResponder];
}




@end
