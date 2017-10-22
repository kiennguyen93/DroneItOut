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

#define RUNNING_DISTANCE_IN_METER   (10)
#define ONE_METER_OFFSET            (0.00000901315)

@interface FollowMeViewController ()<CLLocationManagerDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate>

@property(nonatomic, strong) CLLocationManager* locationManager;
@property(nonatomic, assign) CLLocationCoordinate2D userLocation;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
//currentTarget, target1, target2, prevTarget is "userLocation" at different stages
@property (nonatomic) CLLocationCoordinate2D currentTarget;
//@property (nonatomic) CLLocationCoordinate2D target1;
//@property (nonatomic) CLLocationCoordinate2D target2;
//@property (nonatomic) CLLocationCoordinate2D prevTarget;
@property (nonatomic) CLLocationCoordinate2D aircraftLocation;
//@property (nonatomic) double altitude;


@property (nonatomic, strong) NSTimer* updateTimer;
@property (nonatomic) BOOL isGoingToNorth; //Check if target is moving north
//DJIFollowMeMissionOperator controls, runs and monitors FollowMe Missions
//@property (nonatomic, weak) DJIFollowMeMissionOperator *followMeOperator;
@property (strong, nonatomic) DJIFollowMeMission* followMeMission;

@end

@implementation FollowMeViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startUpdateLocation];
    //self.followMeOperator = [[DJISDKManager missionControl] followMeMissionOperator];
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
    if (error){
        NSString *registerResult = [NSString stringWithFormat:@"Registration Error:%@", error.description];
        ShowMessage(@"Registration Result", registerResult, nil, @"OK");
    }
    else{
#if ENTER_DEBUG_MODE
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"Please Enter Your Debug ID"];
#else
        [DJISDKManager startConnectionToProduct];
#endif
    }
}

- (void)productConnected:(DJIBaseProduct *)product
{
    if (product){
        DJIFlightController* flightController = [DemoUtility fetchFlightController];
        if (flightController) {
            flightController.delegate = self;
        }
    }else{
        ShowMessage(@"Product disconnected", nil, nil, @"OK");
    }
    
    //If this demo is used in China, it's required to login to your DJI account to activate the application. Also you need to use DJI Go app to bind the aircraft to your DJI account. For more details, please check this demo's tutorial.
    [[DJISDKManager userAccountManager] logIntoDJIUserAccountWithAuthorizationRequired:NO withCompletion:^(DJIUserAccountState state, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Login failed: %@", error.description);
        }
    }];
    
}

#pragma mark action Methods
-(DJIFollowMeMissionOperator *)missionOperator {
    return [DJISDKManager missionControl].followMeMissionOperator;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) initializeMission {
    self.followMeMission = [[DJIFollowMeMission alloc] init];
    self.followMeMission.followMeCoordinate = self.userLocation;
    //mission.followMeAltitude = state.altitude;
    self.followMeMission.heading = DJIFollowMeHeadingTowardFollowPosition;
}

- (IBAction)startFollowMe:(UIButton *)sender
{
    //WeakRef(target);
    [self initializeMission];
    [[self missionOperator] startMission:self.followMeMission withCompletion:^(NSError * _Nullable error) {
        if (error) {
            ShowMessage(@"Start Mission Failed", error.description, nil, @"OK");
        } else {
            ShowMessage(@"", @"Mission Started", nil, @"OK");
        }
    }];
    [self startUpdateTimer];
    /*[[self missionOperator] addListenerToEvents:self withQueue:nil andBlock:^(DJIFollowMeMissionEvent * _Nonnull event) {
        [target onReciviedFollowMeEvent:event];
    }];*/
}

- (IBAction)stopFollowMe:(UIButton *)sender
{
    [[self missionOperator] stopMissionWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSString* failedMessage = [NSString stringWithFormat:@"Stop Mission Failed: %@", error.description];
            ShowMessage(@"", failedMessage, nil, @"OK");
        } else {
            [self stopUpdateTimer];
        }
    }];
}

//Use timer for updating the coordinate, letting frequency be 10Hz
//The offset for each interval is 0.1 meter; the following target is moving at speed 1.0 m/s.
-(void) startUpdateTimer {
    if (self.updateTimer == nil) {
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(onUpdateTimerTicked:) userInfo:nil repeats:YES];
    }
    
    [self.updateTimer fire];
}

-(void) pauseUpdateTimer {
    if (self.updateTimer) {
        [self.updateTimer setFireDate:[NSDate distantFuture]];
    }
}

-(void) resumeUpdateTimer {
    if (self.updateTimer) {
        [self.updateTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    }
}

-(void) stopUpdateTimer {
    if (self.updateTimer) {
        [self.updateTimer invalidate];
        self.updateTimer = nil;
    }
}

-(void) onUpdateTimerTicked:(id)sender
{
    /*float offset = 0.0;
    if (self.currentTarget.latitude == self.target1.latitude) {
        offset = -0.1 * ONE_METER_OFFSET;
    }
    else {
        offset = 0.1 * ONE_METER_OFFSET;
    }*/
    
    /*CLLocationManager *locationManager2 = [[CLLocationManager alloc] init];
    if ([CLLocationManager locationServicesEnabled])
    {
        locationManager2.delegate = self;
        locationManager2.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager2.distanceFilter = kCLDistanceFilterNone;
        [locationManager2 startUpdatingLocation];
    }
    CLLocation *location = [locationManager2 location];
    CLLocationCoordinate2D phoneCoordinate = [location coordinate];
    self.target2 = phoneCoordinate;
    self.currentTarget = self.target2;*/
    [[self missionOperator] updateFollowMeCoordinate:self.userLocation];
    
    //self.prevTarget = target;
    
    //[self changeDirectionIfFarEnough];
}

+ (CLLocationDistance) calculateDistanceBetweenPoint:(CLLocationCoordinate2D)point1 andPoint:(CLLocationCoordinate2D)point2 {
    CLLocation* location1 = [[CLLocation alloc] initWithLatitude:point1.latitude longitude:point1.longitude];
    CLLocation* location2 = [[CLLocation alloc] initWithLatitude:point2.latitude longitude:point2.longitude];
    
    return [location1 distanceFromLocation:location2];
}

- (IBAction)loadRootView:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"FollowMeToRootViewSegue" sender:self];
}

-(NSString *)descriptionForState:(DJIFollowMeMissionState)state {
    switch (state) {
        case DJIFollowMeMissionStateUnknown:
            return @"Unknown";
        case DJIFollowMeMissionStateExecuting:
            return @"Executing";
        case DJIFollowMeMissionStateRecovering:
            return @"Recovering";
        case DJIFollowMeMissionStateDisconnected:
            return @"Disconnected";
        case DJIFollowMeMissionStateNotSupported:
            return @"NotSupported";
        case DJIFollowMeMissionStateReadyToStart:
            return @"ReadyToStart";
    }
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

-(void)setAircraftLocation:(CLLocationCoordinate2D)aircraftLocation {
    //aircraftLocation = state.aircraftLocation.coordinate;
    //   self.prepareButton.enabled = NO;
    //   self.pauseButton.enabled = NO;
    //   self.resumeButton.enabled = NsO;
    //   self.downloadButton.enabled = NO;
    // ^Add in these buttons later...
}

/*-(void) changeDirectionIfFarEnough {
    CLLocationDistance distance = [FollowMeViewController calculateDistanceBetweenPoint:self.prevTarget andPoint:self.currentTarget];
    
    // close enough. Change the direction.
    if (distance < 0.2) {
        if (self.currentTarget.latitude == self.target1.latitude) {
            self.currentTarget = self.target2;
        }
        else {
            self.currentTarget = self.target1;
        }
    }
}*/

/*-(void)onReciviedFollowMeEvent:(DJIFollowMeMissionEvent*)event
{
    NSMutableString *statusStr = [NSMutableString new];
    [statusStr appendFormat:@"previousState:%@\n", [[self class] descriptionForState:event.previousState]];
    [statusStr appendFormat:@"currentState:%@\n", [[self class] descriptionForState:event.currentState]];
    [statusStr appendFormat:@"distanceToFollowMeCoordinate:%f\n", event.distanceToFollowMeCoordinate];
    
    if (event.error) {
        [statusStr appendFormat:@"Mission Executing Error:%@", event.error.description];
    }
    //[self.statusLabel setText:statusStr];
}*/

/*-(void)missionDidStart:(NSError *)error {
    // Only starts the updating if the mission is started successfully.
    if (error) return;
    
    self.prevTarget = self.droneLocation;
    self.target1 = self.droneLocation;
    CLLocationManager *locationManager2 = [[CLLocationManager alloc] init];
    if ([CLLocationManager locationServicesEnabled])
    {
        locationManager2.delegate = self;
        locationManager2.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager2.distanceFilter = kCLDistanceFilterNone;
        [locationManager2 startUpdatingLocation];
    }
    CLLocation *location = [locationManager2 location];
    CLLocationCoordinate2D phoneCoordinate = [location coordinate];
    self.target2 = phoneCoordinate;
    self.currentTarget = self.target2;
    
    [self startUpdateTimer];
}*/

@end
