//
//  CameraButton.m
//  Remote Shot
//
//  Created by Luke Wilson on 4/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "CameraButton.h"
#import "CameraViewController.h"
#import <Accelerate/Accelerate.h>

#define ButtonDistanceFromFinger 100
#define ButtonDistancePercentage 0.75
#define ShouldTakePicture(distance) distance > (100/0.75)
#define ShouldTakePictureNow(distance) distance < 45
#define kCameraModePicture 0
#define kCameraModeRapidShot 1
#define kCameraModeVideo 2

#define kLargeFontSize 140
#define kMediumFontSize 120
#define kSmallFontSize 95


@implementation CameraButton

- (void)initialize{
    [self setNeedsLayout];
    self.enabled = YES;
    self.prevDuration = 0;
    self.isAnimatingButton = NO;
    self.rings = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        CAShapeLayer *ring = [CAShapeLayer layer];
        switch (i) {
            case 0:
                ring.strokeColor = [UIColor colorWithRed:61.0/255.0 green:213.0/255.0 blue:251.0/255.0 alpha:255].CGColor;
                break;
            case 1:
                ring.strokeColor = [UIColor blackColor].CGColor;
                break;
            default:
                break;
        }
        ring.lineWidth = 4;
        ring.opacity = 0;
        ring.zPosition = 2;
        ring.position = self.buttonImage.center;
        ring.fillColor   = [UIColor clearColor].CGColor;
        ring.strokeEnd = 0.0;
        ring.bounds = CGRectMake(0, 0, self.buttonImage.frame.size.width-(i*6+3), self.buttonImage.frame.size.height-(i*6+3));
        ring.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, self.buttonImage.frame.size.width-(i*6+3), self.buttonImage.frame.size.height-(i*6+3))].CGPath;
        ring.anchorPoint = CGPointMake(0.5, 0.5);
        ring.transform = CATransform3DMakeRotation(270*(M_PI/180), 0.0, 0.0, 1.0);
        [self.layer addSublayer:ring];
        [self.rings addObject:ring];
    }

    self.ringMoveAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.originalCenterPosition = CGPointMake(screenSize.width/2, screenSize.height-26);
}

- (id)initWithCoder:(NSCoder *)aCoder{
    if(self = [super initWithCoder:aCoder]){
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)rect{
    if(self = [super initWithFrame:rect]){
        [self initialize];
    }
    return self;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
    if (CGRectContainsPoint(self.buttonImage.frame, touchLocation)) {
        self.parentViewController.gestureIsBlocked = YES;
        self.buttonImage.highlightedImage = [self.parentViewController currentHighlightedCameraButtonImage];
        self.buttonImage.highlighted = YES;
    }
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
    float distance = [self distanceBetween:self.originalCenterPosition and:touchLocation];
    if (self.enabled && self.parentViewController.gestureIsBlocked && self.parentViewController.cameraMode == kCameraModePicture) {
        
        float vec[] = {(self.originalCenterPosition.x-touchLocation.x), (self.originalCenterPosition.y-touchLocation.y)};
        float magnitude = sqrtf(vec[0]*vec[0]+vec[1]*vec[1]);
        float normalizedVec[] = {vec[0] / magnitude, vec[1] / magnitude};
        CGPoint buttonPosition;
        if (ShouldTakePicture(distance)) {
            self.buttonImage.highlighted = NO;

            buttonPosition = CGPointMake(touchLocation.x+(ButtonDistanceFromFinger*normalizedVec[0]), touchLocation.y+(ButtonDistanceFromFinger*normalizedVec[1]));
            int duration =[self timerDurationForDistance:distance];
            if (self.prevDuration != duration) {
                [self.parentViewController setCameraButtonText:[NSString stringWithFormat:@"%i", duration] withOffset:CGPointZero fontSize:kLargeFontSize];
                self.prevDuration = duration;
            }

        } else {
            if(ShouldTakePictureNow(distance)) {
                self.buttonImage.highlightedImage = [self.parentViewController currentHighlightedCameraButtonImage];
                self.buttonImage.highlighted = YES;
            } else {
                self.buttonImage.highlighted = NO;
            }
            buttonPosition = CGPointMake(touchLocation.x+((distance*ButtonDistancePercentage)*normalizedVec[0]), touchLocation.y+((distance*ButtonDistancePercentage)*normalizedVec[1]));
            if (self.prevDuration != 0) {
                [self.parentViewController setCameraButtonText:@"" withOffset:CGPointZero fontSize:kLargeFontSize];
                self.prevDuration = 0;
            }
        }
        self.buttonImage.center = buttonPosition;
        for (CAShapeLayer *ring in self.rings) {
            ring.position = self.buttonImage.center;
        }
        [self setNeedsDisplay];
    } else {
        if (CGRectContainsPoint(self.buttonImage.frame, touchLocation) ) {
            self.buttonImage.highlightedImage = [self.parentViewController currentHighlightedCameraButtonImage];
            self.buttonImage.highlighted = YES;
        } else {
            self.buttonImage.highlighted = NO;
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
    if (self.enabled && self.parentViewController.gestureIsBlocked && self.parentViewController.cameraMode == kCameraModePicture) {
        float distance = [self distanceBetween:self.originalCenterPosition and:touchLocation];
        float duration;
        if (ShouldTakePicture(distance)) {
            duration = [self timerDurationForDistance:distance];
            self.timerDuration = (int)duration;
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(countdown:) userInfo:nil repeats:YES];
            
            // start ring animations
            for (int i = 0; i < [self.rings count]; i++) {
                CAShapeLayer *ring = [self.rings objectAtIndex:i];
                ring.opacity = 1;
                
                ring.strokeEnd = 1.0; // set the model ring stroke end
                
                switch (i) {
                    case 0: {
                        CABasicAnimation *endToFront = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
                        endToFront.fromValue   = [NSNumber numberWithFloat:0.0];
                        endToFront.toValue     = [NSNumber numberWithFloat:1.0];
                        endToFront.duration    = 1;
                        
                        // fade out the ring part way thru the animation
                        CABasicAnimation *frontToEnd = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
                        frontToEnd.fromValue   = [NSNumber numberWithFloat:0.0];
                        frontToEnd.toValue     = [NSNumber numberWithFloat:1.0];
                        frontToEnd.duration    = 1;
                        frontToEnd.beginTime = 1;
                        
                        
                        CAAnimationGroup* group = [CAAnimationGroup animation];
                        group.duration    = 2;
                        group.animations  = [NSArray arrayWithObjects:endToFront, frontToEnd, nil];
                        group.repeatCount = duration/2;
                        [ring addAnimation:group forKey:nil];

                        break;
                    }
                    case 1: {
                        
                        CABasicAnimation *ringAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
                        ringAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
                        ringAnimation.toValue = [NSNumber numberWithFloat:1.0f];
                        ringAnimation.duration = duration;
                        ringAnimation.repeatCount = 1;
                        [ring addAnimation:ringAnimation forKey:@"strokeEndAnimation"];

                        break;
                    }
                    default:
                        break;
                }
                
                
                self.ringMoveAnimation.fromValue = [NSValue valueWithCGPoint:ring.position];
                ring.position = self.originalCenterPosition; // set the model ring position
                self.ringMoveAnimation.toValue = [NSValue valueWithCGPoint:self.originalCenterPosition];
                self.ringMoveAnimation.duration = duration;
                [ring addAnimation:self.ringMoveAnimation forKey:@"ringMoveAnimation"];
            }
            self.isAnimatingButton = YES;
//            self.parentViewController.pictureModeButton.enabled = NO;
            self.parentViewController.rapidShotModeButton.enabled = NO;
            self.parentViewController.videoModeButton.enabled = NO;

        } else if (ShouldTakePictureNow(distance)) {
            [self.parentViewController pressedCameraButton];
            duration = 0.1;
        } else {
            duration = 0.1;
        }

        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.buttonImage.center = self.originalCenterPosition;
        } completion:^(BOOL finished){
            if (finished && ShouldTakePicture(distance)) {
                for (CAShapeLayer *ring in self.rings) {
                    ring.opacity = 0;
                }
                [self.parentViewController pressedCameraButton];
                self.isAnimatingButton = NO;
                self.parentViewController.gestureIsBlocked = NO;
//                self.parentViewController.pictureModeButton.enabled = YES;
                self.parentViewController.rapidShotModeButton.enabled = YES;
                self.parentViewController.videoModeButton.enabled = YES;
            }
        }];
    } else {
        if (CGRectContainsPoint(self.buttonImage.frame, touchLocation) ) {
            [self.parentViewController pressedCameraButton];
        }
    }
    self.buttonImage.highlighted = NO;
    if (!self.isAnimatingButton) self.parentViewController.gestureIsBlocked = NO;
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

// Only take touches that are inside the camera button
-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.isAnimatingButton || self.parentViewController.settingsMenuIsOpen) {
        return NO;
    } else if (CGRectContainsPoint(self.buttonImage.frame, point)) {
        return YES;
    }
    return NO;
}

-(int)timerDurationForDistance:(float)distance {
    return distance/50;
}

-(float)distanceBetween:(CGPoint)point1 and:(CGPoint)point2 {
    float xDif =point2.x-point1.x;
    float yDif = point2.y-point1.y;
    return sqrtf(xDif*xDif + yDif*yDif);
}

-(void)countdown:(NSTimer *)timer {
    self.timerDuration--;
    if (self.timerDuration > 0) {
        [self.parentViewController setCameraButtonText:[NSString stringWithFormat:@"%i", self.timerDuration] withOffset:CGPointZero fontSize:kLargeFontSize];
    } else {
        [timer invalidate];
        [self.parentViewController setCameraButtonText:@"" withOffset:CGPointZero fontSize:kLargeFontSize];
    }
}


//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
//}


@end
