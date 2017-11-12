//
//  FollowMeViewController.m
//  DroneItOut
//
//  Created by Eric Hernandez-Lu on 9/28/17.
//  Copyright © 2017 Eric Hernandez-Lu. All rights reserved.
//

#import "FollowMeViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <DJISDK/DJISDK.h>
#import "DemoUtility.h"

#define ENTER_DEBUG_MODE 0

@interface FollowMeViewController ()<CLLocationManagerDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate>

@property(nonatomic, strong) CLLocationManager* locationManager;
@property(nonatomic, assign) CLLocationCoordinate2D userLocation;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
@property (nonatomic) CLLocationCoordinate2D currentTarget;
@property (nonatomic) CLLocationCoordinate2D aircraftLocation;

@property (nonatomic, strong) NSTimer* updateTimer;
@property (nonatomic) BOOL isGoingToNorth; //Check if target is moving north
@property (nonatomic, weak) DJIFollowMeMissionOperator *followMeOperator;
@property (strong, nonatomic) DJIFollowMeMission* followMeMission;

@end

@implementation FollowMeViewController

- (void)viewWillAppear:(BOOL)animated
{
    [self startUpdateLocation];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.locationManager stopUpdatingLocation];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self registerApp];
    [self initData];
}

#pragma mark Init Methods
-(void)initData
{
    self.userLocation = kCLLocationCoordinate2DInvalid;
    self.droneLocation = kCLLocationCoordinate2DInvalid;
}

-(void) registerApp
{
    //Please enter your App key in the info.plist file to register the app.
    [DJISDKManager registerAppWithDelegate:self];
}

#pragma mark DJISDKManagerDelegate Methods
- (void)appRegisteredWithError:(NSError *)error
{
    if (error)
    {
        NSString *registerResult = [NSString stringWithFormat:@"Registration Error:%@", error.description];
        ShowMessage(@"Registration Result", registerResult, nil, @"OK");
    }
    else
    {
#if ENTER_DEBUG_MODE
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"Please Enter Your Debug ID"];
#else
        [DJISDKManager startConnectionToProduct];
#endif
    }
}

- (void)productConnected:(DJIBaseProduct *)product
{
    if (product)
    {
        DJIFlightController* flightController = [DemoUtility fetchFlightController];
        if (flightController)
        {
            flightController.delegate = self;
        }
    }
    else
    {
        ShowMessage(@"Product disconnected", nil, nil, @"OK");
    }
    
    //If this demo is used in China, it's required to login to your DJI account to activate the application. Also you need to use DJI Go app to bind the aircraft to your DJI account. For more details, please check this demo's tutorial.
    [[DJISDKManager userAccountManager] logIntoDJIUserAccountWithAuthorizationRequired:NO withCompletion:^(DJIUserAccountState state, NSError * _Nullable error)
    {
        if (error)
        {
            NSLog(@"Login failed: %@", error.description);
        }
    }];
    
}

#pragma mark action Methods
-(DJIFollowMeMissionOperator *)missionOperator
{
    return [DJISDKManager missionControl].followMeMissionOperator;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) initializeMission
{
    self.followMeOperator = [self missionOperator];
    self.followMeMission = [[DJIFollowMeMission alloc] init];
    self.followMeMission.followMeCoordinate = self.userLocation;
    self.followMeMission.heading = DJIFollowMeHeadingTowardFollowPosition;
}

- (IBAction)startFollowMe:(UIButton *)sender
{
    [self initializeMission];
    [self.followMeOperator startMission:self.followMeMission withCompletion:^(NSError * _Nullable error)
    {
        if (error)
        {
            ShowMessage(@"Start Mission Failed", error.description, nil, @"OK");
        }
        else
        {
            ShowMessage(@"", @"Mission Started", nil, @"OK");
        }
    }];
    [self startUpdateTimer];
}

- (IBAction)stopFollowMe:(UIButton *)sender
{
    [self.followMeOperator stopMissionWithCompletion:^(NSError * _Nullable error)
    {
        if (error)
        {
            NSString* failedMessage = [NSString stringWithFormat:@"Stop Mission Failed: %@", error.description];
            ShowMessage(@"", failedMessage, nil, @"OK");
        }
        else
        {
            [self stopUpdateTimer];
        }
    }];
}

//Use timer for updating the coordinate, letting frequency be 10Hz
-(void) startUpdateTimer
{
    if (self.updateTimer == nil)
    {
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(onUpdateTimerTicked:) userInfo:nil repeats:YES];
    }
    
    [self.updateTimer fire];
}

-(void) pauseUpdateTimer
{
    if (self.updateTimer)
    {
        [self.updateTimer setFireDate:[NSDate distantFuture]];
    }
}

-(void) resumeUpdateTimer
{
    if (self.updateTimer)
    {
        [self.updateTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    }
}

-(void) stopUpdateTimer
{
    if (self.updateTimer)
    {
        [self.updateTimer invalidate];
        self.updateTimer = nil;
    }
}

-(void) onUpdateTimerTicked:(id)sender
{
    [self.followMeOperator updateFollowMeCoordinate:self.userLocation];
}

- (IBAction)loadRootView:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"FollowMeToRootViewSegue" sender:self];
}

#pragma mark CLLocation Methods
-(void) startUpdateLocation
{
    if ([CLLocationManager locationServicesEnabled])
    {
        if (self.locationManager == nil)
        {
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.delegate = self;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            self.locationManager.distanceFilter = 0.1;
            if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
            {
                [self.locationManager requestAlwaysAuthorization];
            }
            [self.locationManager startUpdatingLocation];
        }
    }
    else
    {
        ShowMessage(@"Location Service is not available", @"", nil, @"OK");
    }
}

#pragma mark DJIFlightControllerDelegate
- (void)flightController:(DJIFlightController *)fc didUpdateState:(DJIFlightControllerState *)state
{
    self.droneLocation = state.aircraftLocation.coordinate;
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    self.userLocation = location.coordinate;
}

-(void)setAircraftLocation:(CLLocationCoordinate2D)aircraftLocation
{
    
}

- (void) callStartFollowMe
{
    [self startFollowMe:nil];
}

- (void) callStopFollowMe
{
    [self startFollowMe:nil];
}
@end
