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

@interface FollowMeViewController ()<CLLocationManagerDelegate>

@property(nonatomic, strong) CLLocationManager* locationManager;
@property(nonatomic, assign) CLLocationCoordinate2D userLocation;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
//currentTarget, target1, target2, prevTarget is "userLocation" at different stages
@property (nonatomic) CLLocationCoordinate2D currentTarget;
@property (nonatomic) CLLocationCoordinate2D target1;
@property (nonatomic) CLLocationCoordinate2D target2;
@property (nonatomic) CLLocationCoordinate2D prevTarget;

@property (nonatomic, strong) NSTimer* updateTimer;
@property (nonatomic) BOOL isGoingToNorth; //Check if target is moving north
//DJIFollowMeMissionOperator controls, runs and monitors FollowMe Missions
@property (nonatomic, weak) DJIFollowMeMissionOperator *followMeOperator;

@end

@implementation FollowMeViewController
@synthesize droneLocation = _aircraftLocation; //Letting "droneLocation" replace "aircraftLocation"?? Not sure if it will work.


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startUpdateLocation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.locationManager stopUpdatingLocation];
}

-(void)setAircraftLocation:(CLLocationCoordinate2D)droneLocation {
    _aircraftLocation = droneLocation;
    //   self.prepareButton.enabled = NO;
    //   self.pauseButton.enabled = NO;
    //   self.resumeButton.enabled = NO;
    //   self.downloadButton.enabled = NO;
    // ^Add in these buttons later...
}

-(DJIMission*) initializeMission {
    DJIFollowMeMission* mission = [[DJIFollowMeMission alloc] init];
    mission.followMeCoordinate = self.droneLocation;
    mission.heading = DJIFollowMeHeadingTowardFollowPosition;
    
    return mission;
}

- (IBAction)loadRootView:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"FollowMeToRootViewSegue" sender:self];
}

- (IBAction)startFollowMe:(UIButton *)sender
{
    WeakRef(target);
    DJIFollowMeMission* mission = (DJIFollowMeMission*)[self initializeMission];
    [self.followMeOperator startMission:mission withCompletion:^(NSError * _Nullable error) {
        if (error) {
            ShowMessage(@"", @"Start Mission Failed:%@", error, @"OK");
        } else {
            [target missionDidStart:error];
        }
    }];
    
    [self.followMeOperator addListenerToEvents:self withQueue:nil andBlock:^(DJIFollowMeMissionEvent * _Nonnull event) {
        [target onReciviedFollowMeEvent:event];
    }];
}

- (IBAction)stopFollowMe:(UIButton *)sender
{
    WeakRef(target);
    [self.followMeOperator stopMissionWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            ShowMessage(@"", @"Stop Mission Failed:%@", error.description, @"OK");
        } else {
            [target startUpdateTimer];
            [target.followMeOperator removeListener:self];
        }
    }];
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
    float offset = 0.0;
    if (self.currentTarget.latitude == self.target1.latitude) {
        offset = -0.1 * ONE_METER_OFFSET;
    }
    else {
        offset = 0.1 * ONE_METER_OFFSET;
    }
    
    CLLocationCoordinate2D target = CLLocationCoordinate2DMake(self.prevTarget.latitude + offset, self.prevTarget.longitude);
    [self.followMeOperator updateFollowMeCoordinate:target];
    
    self.prevTarget = target;
    
    [self changeDirectionIfFarEnough];
}

-(void) changeDirectionIfFarEnough {
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
}

+ (CLLocationDistance) calculateDistanceBetweenPoint:(CLLocationCoordinate2D)point1 andPoint:(CLLocationCoordinate2D)point2 {
    CLLocation* location1 = [[CLLocation alloc] initWithLatitude:point1.latitude longitude:point1.longitude];
    CLLocation* location2 = [[CLLocation alloc] initWithLatitude:point2.latitude longitude:point2.longitude];
    
    return [location1 distanceFromLocation:location2];
}


#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    self.userLocation = location.coordinate;
}

-(void)onReciviedFollowMeEvent:(DJIFollowMeMissionEvent*)event
{
    NSMutableString *statusStr = [NSMutableString new];
    [statusStr appendFormat:@"previousState:%@\n", [[self class] descriptionForState:event.previousState]];
    [statusStr appendFormat:@"currentState:%@\n", [[self class] descriptionForState:event.currentState]];
    [statusStr appendFormat:@"distanceToFollowMeCoordinate:%f\n", event.distanceToFollowMeCoordinate];
    
    if (event.error) {
        [statusStr appendFormat:@"Mission Executing Error:%@", event.error.description];
    }
    //[self.statusLabel setText:statusStr];
}

-(void)missionDidStart:(NSError *)error {
    // Only starts the updating if the mission is started successfully.
    if (error) return;
    
    self.prevTarget = self.droneLocation;
    self.target1 = self.droneLocation;
    CLLocationManager *locationManager2 = [[CLLocationManager alloc] init];
    CLLocation *location = [locationManager2 location];
    CLLocationCoordinate2D phoneCoordinate = [location coordinate];
    self.target2 = phoneCoordinate;
    self.currentTarget = self.target2;
    
    [self startUpdateTimer];
}

+(NSString *)descriptionForState:(DJIFollowMeMissionState)state {
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


@end
