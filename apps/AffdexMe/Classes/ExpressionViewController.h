//
//  ExpressionViewController.h
//  AffdexMe
//
//  Created by Boisy Pitre on 2/14/14.
//  Copyright (c) 2016 Affectiva. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ExpressionViewController : UIViewController
{
    float _metric;
}

@property (strong) IBOutlet UILabel *expressionLabel;
@property (strong) IBOutlet UILabel *scoreLabel;
@property (strong) IBOutlet UIView *indicatorView;
@property (strong) NSString *name;
@property (assign) float metric;

- (void)faceDetected;
- (void)faceUndetected;
- (void)reset;

- (id)initWithName:(NSString *)name deviceIsPhone:(BOOL)iPhoneInUse;

@end
