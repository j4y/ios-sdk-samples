//
//  ExpressionViewController.m
//  AffdexMe
//
//  Created by Boisy Pitre on 2/14/14.
//  Copyright (c) 2016 Affectiva. All rights reserved.
//

#import "ExpressionViewController.h"

@interface ExpressionViewController ()

@property (assign) CGRect indicatorBounds;

@end

@implementation ExpressionViewController

@dynamic metric;

- (id)initWithName:(NSString *)name deviceIsPhone:(BOOL)iPhoneInUse;
{
    if (iPhoneInUse)
    {
        self = [super initWithNibName:@"ExpressionView_iPhone" bundle:nil];
    }
    else
    {
        self = [super initWithNibName:@"ExpressionView_iPad" bundle:nil];
    }

    if (self)
    {
        self.name = name;
    }
    
    return self;
}

- (void)reset;
{
//    self.view.alpha = 0.0;
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    CGFloat labelSize = self.expressionLabel.font.pointSize;
    CGFloat scoreSize = self.scoreLabel.font.pointSize;
    
    self.expressionLabel.font = [UIFont fontWithName:@"SquareFont" size:labelSize];
    self.expressionLabel.backgroundColor = [UIColor clearColor];
    self.expressionLabel.shadowColor = [UIColor blackColor];
    self.expressionLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    self.expressionLabel.text = self.name;

    self.scoreLabel.font = [UIFont fontWithName:@"SquareFont" size:scoreSize];
    
    self.indicatorBounds = self.indicatorView.bounds;
    [self setMetric:0.0];
}

- (float)metric;
{
    return _metric;
}

- (void)setMetric:(float)value;
{
    _metric = value;
    if (!isnan(value))
    {
        CGRect bounds = self.indicatorBounds;
        if (isnan(value))
        {
            bounds.size.width = 0.0;
        }
        else
        {
            bounds.size.width *= (value / 100.0);
        }
        
        if (value < 0.0)
        {
            [self.indicatorView setBackgroundColor:[UIColor redColor]];
        }
        else
        {
            [self.indicatorView setBackgroundColor:[UIColor greenColor]];
        }

        [self.indicatorView setBounds:bounds];
        self.scoreLabel.text = [NSString stringWithFormat:@"%.0f%%", value];
//        float alphaValue = fmax(fabs(value) / 100.0, 0.35);
//        self.view.alpha = alphaValue;
    }
}

- (void)faceDetected;
{
}

- (void)faceUndetected;
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.25];
//    [self.view setAlpha:0.0];
    [UIView commitAnimations];
}

@end
