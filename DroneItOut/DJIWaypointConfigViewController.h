//
//  DJIWaypointConfigViewController.h
//  DroneItOut
//
//  Created by Kien Nguyen on 9/6/2017.
//  Copyright (c) 2017 Kien Nguyen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DJIWaypointConfigViewController;

@protocol DJIWaypointConfigViewControllerDelegate <NSObject>

- (void)cancelBtnActionInDJIWaypointConfigViewController:(DJIWaypointConfigViewController *)waypointConfigVC;
- (void)finishBtnActionInDJIWaypointConfigViewController:(DJIWaypointConfigViewController *)waypointConfigVC;

@end

@interface DJIWaypointConfigViewController : UIViewController{
    IBOutlet UITextField *altitude;
    IBOutlet UITextField *autoFlightSpeed;
    IBOutlet UITextField *maxSpeed;
}
    

- (IBAction)altitudeDismiss:(id)sender;
- (IBAction)autoFlightSpeedDismiss:(id)sender;
- (IBAction)maxSpeedDismiss:(id)sender;



@property (weak, nonatomic) IBOutlet UITextField *altitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *autoFlightSpeedTextField;
@property (weak, nonatomic) IBOutlet UITextField *maxFlightSpeedTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *actionSegmentedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *headingSegmentedControl;

@property (weak, nonatomic) id <DJIWaypointConfigViewControllerDelegate>delegate;

- (IBAction)cancelBtnAction:(id)sender;
- (IBAction)finishBtnAction:(id)sender;

@end
