//
//  SAScrubber.m
//  Pods
//
//  Created by Luke Wilson on 5/16/14.
//
//

#import "SAScrubber.h"

@implementation SAScrubber

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGRect frame = CGRectMake(rect.origin.x+rect.size.width/4, rect.origin.y, rect.size.width/2, rect.size.height);
    //// Color Declarations
    UIColor* color = [UIColor colorWithRed:0.905 green:0.936 blue:0.957 alpha:1.000];
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), CGRectGetHeight(frame)) cornerRadius: 5];
    [color setFill];
    [rectanglePath fill];
}



@end
