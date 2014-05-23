//
//  MoveableImageView.m
//  Remote Shot
//
//  Created by Luke Wilson on 3/20/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "MoveableImageView.h"
#import "CameraViewController.h"

#define kFocusViewTag 1
#define kExposeViewTag 2

@implementation MoveableImageView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
    self.center = touchLocation;
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
    self.center = touchLocation;
    if (self.tag == kExposeViewTag) {
        [self.parentViewController.videoProcessor exposeAtPoint:[self.parentViewController devicePointForScreenPoint:touchLocation]];
    } else if (self.tag == kFocusViewTag){
        [self.parentViewController.videoProcessor focusAtPoint:[self.parentViewController devicePointForScreenPoint:touchLocation]];
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(void)fixIfOffscreen {
    if (self.frame.origin.x < 0) {
        self.frame = CGRectMake(0, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
    } else if (self.frame.origin.x+self.frame.size.width > self.superview.frame.size.width) {
        self.frame = CGRectMake(self.superview.frame.size.width-self.frame.size.width, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
    }
    if (self.frame.origin.y < 0) {
        self.frame = CGRectMake(self.frame.origin.x, 0, self.frame.size.width, self.frame.size.height);
    } else if (self.frame.origin.y+self.frame.size.height > self.superview.frame.size.height) {
        self.frame = CGRectMake(self.frame.origin.x, self.superview.frame.size.height-self.frame.size.height, self.frame.size.width, self.frame.size.height);
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
