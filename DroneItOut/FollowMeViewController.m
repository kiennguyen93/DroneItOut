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

@interface FollowMeViewController ()<CLLocationManagerDelegate>

@property(nonatomic, strong) CLLocationManager* locationManager;
@property(nonatomic, assign) CLLocationCoordinate2D userLocation;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;

@end

@implementation FollowMeViewController

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

- (IBAction)loadRootView:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"FollowMeToRootViewSegue" sender:self];
}

- (IBAction)raiseAltitude:(UIButton *)sender
{
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

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    self.userLocation = location.coordinate;
}

@end
