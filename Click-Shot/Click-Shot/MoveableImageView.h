//
//  MoveableImageView.h
//  Remote Shot
//
//  Created by Luke Wilson on 3/20/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CameraViewController;
@interface MoveableImageView : UIImageView

@property (nonatomic, strong) UITouch *primaryTouch;
@property (nonatomic, strong) CameraViewController *parentViewController;
@property (nonatomic, strong) NSString *touchEndSelectorName;
-(void)fixIfOffscreen;


@end
