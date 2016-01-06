//
//  AffdexDemoViewController.h
//  faceDetection
//
//  Created by Affectiva on 2/22/13.
//  Copyright (c) 2016 Affectiva All rights reserved.
//

#import "SoundEffect.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ExpressionViewController.h"
#import <Affdex/Affdex.h>

@interface AffdexDemoViewController : UIViewController <AFDXDetectorDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong) IBOutlet UIImageView *imageView;
@property (weak) IBOutlet UIImageView *processedImageView;
@property (strong) AVCaptureSession *session;
@property dispatch_queue_t process_queue;
@property (weak) IBOutlet UILabel *fps;
@property (weak) IBOutlet UILabel *fpsProcessed;
@property (weak) IBOutlet UILabel *detectors;
@property (weak) IBOutlet UILabel *appleDetectors;
@property (strong) AFDXDetector *detector;
@property (assign) BOOL drawFacePoints;
@property (assign) BOOL drawAppearanceIcons;
@property (assign) BOOL drawFaceRect;
@property (strong) NSMutableDictionary *faceMeasurements;
@property (weak) IBOutlet UIView *classifiersView;
@property (weak) IBOutlet UIButton *cameraButton_compact;
@property (weak) IBOutlet UIButton *cameraButton_regular;
@property (weak) IBOutlet UIButton *cameraSwapButton_compact;
@property (weak) IBOutlet UIButton *cameraSwapButton_regular;

@property (weak) IBOutlet UIView *classifierHeaderView_compact;
@property (weak) IBOutlet UIView *classifierHeaderView_regular;

@property (strong) NSMutableArray *selectedClassifiers;
@property (weak) IBOutlet UIView *classifier1View_compact;
@property (weak) IBOutlet UIView *classifier2View_compact;
@property (weak) IBOutlet UIView *classifier3View_compact;
@property (weak) IBOutlet UIView *classifier4View_compact;
@property (weak) IBOutlet UIView *classifier5View_compact;
@property (weak) IBOutlet UIView *classifier6View_compact;

@property (weak) IBOutlet UIView *classifier1View_regular;
@property (weak) IBOutlet UIView *classifier2View_regular;
@property (weak) IBOutlet UIView *classifier3View_regular;
@property (weak) IBOutlet UIView *classifier4View_regular;
@property (weak) IBOutlet UIView *classifier5View_regular;
@property (weak) IBOutlet UIView *classifier6View_regular;

@property (weak) IBOutlet UILabel *versionLabel;
@property (strong) SoundEffect *sound;


- (void)startDetector;
- (void)stopDetector;

- (IBAction)cameraButtonTouched:(id)sender;
- (IBAction)cameraSwapButtonTouched:(id)sender;

@end
