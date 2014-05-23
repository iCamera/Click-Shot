//
//  CameraButton.h
//  Remote Shot
//
//  Created by Luke Wilson on 4/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CameraViewController;
@interface CameraButton : UIView

//@property (nonatomic, strong) UITouch *primaryTouch;
@property (nonatomic, strong) CameraViewController *parentViewController;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) BOOL isAnimatingButton;

@property (nonatomic) CGPoint originalCenterPosition;

@property (nonatomic, weak) IBOutlet UIImageView *buttonImage;
@property (nonatomic, strong) NSMutableArray *rings;


@property (nonatomic, strong) CABasicAnimation *ringMoveAnimation;

@property (nonatomic) int timerDuration;
@property (nonatomic) int prevDuration; // for not recreating the button image too many times

- (void)initialize;


@end
