//
//  DJIAircraftAnnotationView.h
//  DroneItOut
//
//  Created by Kien Nguyen on 9/6/2017.
//  Copyright (c) 2017 Kien Nguyen. All rights reserved.
//


#import <MapKit/MapKit.h>

@interface DJIAircraftAnnotationView : MKAnnotationView

-(void) updateHeading:(float)heading;

@end
