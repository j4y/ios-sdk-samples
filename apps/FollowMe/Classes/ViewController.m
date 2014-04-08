//
//  ViewController.m
//
//  Created by Affectiva on 2/22/13.
//  Copyright (c) 2013 Affectiva All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak) IBOutlet UIButton *browFurrowView;
@property (weak) IBOutlet UIButton *smileView;
@property (weak) IBOutlet UIButton *browRaiseView;
@property (weak) IBOutlet UIButton *lipCornerDepressorView;
@property (weak) IBOutlet UIButton *valenceView;
@property (weak) IBOutlet UILabel *smileScore;
@property (weak) IBOutlet UILabel *browFurrowScore;
@property (weak) IBOutlet UILabel *browRaiseScore;
@property (weak) IBOutlet UILabel *lipCornerDepressorScore;
@property (weak) IBOutlet UILabel *valenceScore;
@property (strong) NSDate *dateOfLastFrame;
@property (strong) NSDate *dateOfLastProcessedFrame;

@end

@implementation ViewController

#pragma mark
#pragma mark ViewController Delegate Methods

- (void)resetUI;
{
    self.fps.text = @"";
    self.fpsProcessed.text = @"";
    self.detectors.text = @"";
    self.appleDetectors.text = @"";
    
    [self.browFurrowView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateNormal];
    [self.browFurrowView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    [self.browFurrowView setSelected:TRUE];
    self.browFurrowView.tag = 101;
    
    [self.smileView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateNormal];
    [self.smileView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    [self.smileView setSelected:TRUE];
    self.smileView.tag = 102;
    
    [self.browRaiseView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateNormal];
    [self.browRaiseView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    [self.browRaiseView setSelected:TRUE];
    self.browRaiseView.tag = 103;
    
    [self.lipCornerDepressorView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateNormal];
    [self.lipCornerDepressorView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    [self.lipCornerDepressorView setSelected:TRUE];
    self.lipCornerDepressorView.tag = 104;
    
    [self.valenceView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateNormal];
    [self.valenceView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    [self.valenceView setSelected:TRUE];
    self.valenceView.tag = 105;
    
    self.smileScore.text = @"0%";
    self.browFurrowScore.text = @"0%";
    self.browRaiseScore.text = @"0%";
    self.lipCornerDepressorScore.text = @"0%";
    self.valenceScore.text = @"0%";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // setup views
    self.ledView.image = [UIImage imageNamed:@"LED-Red.png"];
    [self.view addSubview:self.imageView];
    
    [self resetUI];
    
    // create our detector with our desired facial expresions, using the front facing camera
    self.detector = [[AFDXDetector alloc] initWithDelegate:self
                                               usingCamera:AFDX_CAMERA_FRONT];
    
    // tell the detector which facial expressions we want to measure
    self.detector.smile = TRUE;
    self.detector.browRaise = TRUE;
    self.detector.browFurrow = TRUE;
    self.detector.lipCornerDepressor = TRUE;
    self.detector.valence = TRUE;
    self.detector.sendUnprocessedFrames = FALSE;
    
    self.detector.maxProcessRate = 30.f;
    
    self.dateOfLastFrame = nil;
    self.dateOfLastProcessedFrame = nil;
    self.detector.licensePath = [[NSBundle mainBundle] pathForResource:@"sdk" ofType:@"license"];
    
    // let's start it up!
    NSError *error = [self.detector start];
    
    if (nil != error)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Detector Error" message:[error localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alert show];
    }
}

- (void)dealloc;
{
    self.detector = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)addSubView:(UIView *)highlitView withFrame:(CGRect)frame
{
    highlitView.frame = frame;
    highlitView.layer.borderWidth = 1;
    highlitView.layer.borderColor = [[UIColor whiteColor] CGColor];
    [self.imageView addSubview:highlitView];
}


#pragma mark -
#pragma mark AFDXDetectorDelegate Methods

- (void)detectorDidFinishProcessing:(AFDXDetector *)detector;
{
}

- (void)detectorDidStartDetectingFace:(AFDXDetector *)detector;
{
    [self.ledView setImage:[UIImage imageNamed:@"LED-Green"]];
}

- (void)detectorDidStopDetectingFace:(AFDXDetector *)detector;
{
    [self.ledView setImage:[UIImage imageNamed:@"LED-Red"]];
    [self resetUI];
}

- (void)detector:(AFDXDetector *)detector hasResults:(NSArray *)metrics forImage:(UIImage *)image atTime:(NSTimeInterval)time;
{
    // Since all video frames are now passed, we determine if this is an "analyzed" frame by looking at the
    // metrics object. If it's nil, we merely set the image of our image view to the passed image, and do
    // some math to compute the frame rate.
    if (nil == metrics)
    {
        [self.imageView setImage:image];
    }
    else if(FALSE == self.detector.sendUnprocessedFrames) // avoid redundant setting of image
    {
        [self.imageView setImage:image];
    }
    
    if (nil == metrics)
    {
        // compute frames per second and show
        NSDate *now = [NSDate date];
        
        if (nil != self.dateOfLastFrame)
        {
            NSTimeInterval interval = [now timeIntervalSinceDate:self.dateOfLastFrame];
            
            if (interval > 0)
            {
                float fps = 1.0 / interval;
                self.fps.text = [NSString stringWithFormat:@"FPS(C): %.1f", fps];
            }
        }
        
        self.dateOfLastFrame = now;
    }
    else
    {
        // This frame has metrics data, so it has been processed by the detector.
        // Well compute the frame rate for processed frames (P)
        NSDate *now = [NSDate date];
        
        if (nil != self.dateOfLastProcessedFrame)
        {
            NSTimeInterval interval = [now timeIntervalSinceDate:self.dateOfLastProcessedFrame];
            
            if (interval > 0)
            {
                float fps = 1.0 / interval;
                self.fpsProcessed.text = [NSString stringWithFormat:@"FPS(P): %.1f", fps];
            }
        }
        
        self.dateOfLastProcessedFrame = now;
        
        // Handle each metric in the array
        for (AFDXMetric *metric in metrics)
        {
            // dispatch the metric to the appropriate handler
            if ([metric isKindOfClass:[AFDXSmileMetric class]])
            {
                [self handleSmile:(AFDXSmileMetric *)metric];
            }
            else
                if ([metric isKindOfClass:[AFDXBrowFurrowMetric class]])
                {
                    [self handleBrowFurrow:(AFDXBrowFurrowMetric *)metric];
                }
                else
                    if ([metric isKindOfClass:[AFDXBrowRaiseMetric class]])
                    {
                        [self handleBrowRaise:(AFDXBrowRaiseMetric *)metric];
                    }
                    else
                        if ([metric isKindOfClass:[AFDXLipCornerDepressorMetric class]])
                        {
                            [self handleLipCornerDepressor:(AFDXLipCornerDepressorMetric *)metric];
                        }
                        else
                            if ([metric isKindOfClass:[AFDXValenceMetric class]])
                            {
                                [self handleValence:(AFDXValenceMetric *)metric];
                            }
        }
    }
}


#pragma mark -
#pragma mark Metric-Specific Methods

- (void)handleSmile:(AFDXSmileMetric *)metric;
{
    float prob = [metric.value floatValue];
    
    if (isnan(prob))
    {
        self.smileScore.text = @"---";
    }
    else
    {
        self.smileScore.text = [NSString stringWithFormat:@"%.0f%%", prob];
    }
    
    if (prob > 80.0)
    {
        [self.smileView setImage:[UIImage imageNamed:@"Face_SmileHuge"] forState:UIControlStateSelected];
    }
    else
        if (prob > 60.0)
        {
            [self.smileView setImage:[UIImage imageNamed:@"Face_Smile"] forState:UIControlStateSelected];
        }
        else
        {
            [self.smileView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
        }
}

- (void)handleBrowFurrow:(AFDXBrowFurrowMetric *)metric;
{
    float prob = [metric.value floatValue];
    
    if (isnan(prob))
    {
        self.browFurrowScore.text = @"---";
    }
    else
    {
        self.browFurrowScore.text = [NSString stringWithFormat:@"%.0f%%", prob];
    }
    
    if (prob > 60.0)
    {
        [self.browFurrowView setImage:[UIImage imageNamed:@"Face_Sleep"] forState:UIControlStateSelected];
    }
    else
    {
        [self.browFurrowView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    }
}

- (void)handleBrowRaise:(AFDXBrowRaiseMetric *)metric;
{
    float prob = [metric.value floatValue];
    
    if (isnan(prob))
    {
        self.browRaiseScore.text = @"---";
    }
    else
    {
        self.browRaiseScore.text = [NSString stringWithFormat:@"%.0f%%", prob];
    }
    
    if (prob > 60.0)
    {
        [self.browRaiseView setImage:[UIImage imageNamed:@"Face_Surprise"] forState:UIControlStateSelected];
    }
    else
    {
        [self.browRaiseView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    }
}

- (void)handleLipCornerDepressor:(AFDXLipCornerDepressorMetric *)metric;
{
    float prob = [metric.value floatValue];
    
    if (isnan(prob))
    {
        self.lipCornerDepressorScore.text = @"---";
    }
    else
    {
        self.lipCornerDepressorScore.text = [NSString stringWithFormat:@"%.0f%%", prob];
    }
    
    if (prob > 60.0)
    {
        [self.lipCornerDepressorView setImage:[UIImage imageNamed:@"Face_Sadness"] forState:UIControlStateSelected];
    }
    else
    {
        [self.lipCornerDepressorView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    }
}

- (void)handleValence:(AFDXValenceMetric *)metric;
{
    float prob = [metric.value floatValue];
    
    if (isnan(prob))
    {
        self.valenceScore.text = @"---";
    }
    else
    {
        self.valenceScore.text = [NSString stringWithFormat:@"%.0f%%", prob];
    }
    
    if (prob >= 25.0)
    {
        [self.valenceView setImage:[UIImage imageNamed:@"Face_Smile"] forState:UIControlStateSelected];
    }
    else if (prob <= -25.0)
    {
        [self.valenceView setImage:[UIImage imageNamed:@"Face_Sadness"] forState:UIControlStateSelected];
    }
    else
    {
        [self.valenceView setImage:[UIImage imageNamed:@"Face_Neutral"] forState:UIControlStateSelected];
    }
}

#pragma mark -
#pragma mark Button Processing Method

// Future: we want to be able to turn on or off a facial expression while the engine is still running.
- (IBAction)handleButtonTouch:(UIButton *)sender;
{
    [sender setSelected:!sender.selected];
    AFDXMetric *nanMetric = [[AFDXMetric alloc] initWithValue:[NSNumber numberWithDouble:NAN]];
    
    switch ([sender tag])
    {
        case 101: // Brow Furrow
            self.detector.browFurrow = sender.selected;
            if (NO == sender.selected) [self handleBrowFurrow:(AFDXBrowFurrowMetric *)nanMetric];
            break;
            
        case 102: // Smile
            self.detector.smile = sender.selected;
            if (NO == sender.selected) [self handleSmile:(AFDXSmileMetric *)nanMetric];
            break;
            
        case 103: // Brow Raise
            self.detector.browRaise = sender.selected;
            if (NO == sender.selected) [self handleBrowRaise:(AFDXBrowRaiseMetric *)nanMetric];
            break;
            
        case 104: // Lip Corner Depressor
            self.detector.lipCornerDepressor = sender.selected;
            if (NO == sender.selected) [self handleLipCornerDepressor:(AFDXLipCornerDepressorMetric *)nanMetric];
            break;
            
        case 105: // valence
            self.detector.valence = sender.selected;
            if (NO == sender.selected) [self handleValence:(AFDXValenceMetric *)nanMetric];
            break;
    }
}

@end
