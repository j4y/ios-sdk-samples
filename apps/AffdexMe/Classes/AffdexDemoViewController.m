//
//  AffdexDemoViewController.m
//
//  Created by Affectiva on 2/22/13.
//  Copyright (c) 2016 Affectiva All rights reserved.
//

// If this feature is turned on, then emotions and expressions will be sent via UDP
#undef BROADCAST_VIA_UDP
#ifdef BROADCAST_VIA_UDP
#define MULTICAST_GROUP @"224.0.1.1"
#define MULTICAST_PORT 12345
#endif

// If this is being compiled for the iOS simulator, a demo mode is used since the camera isn't supported.
#if TARGET_IPHONE_SIMULATOR
#define DEMO_MODE
#endif

#import "UIDeviceHardware.h"
#import "AffdexDemoViewController.h"
#ifdef BROADCAST_VIA_UDP
#import "GCDAsyncUdpSocket.h"
#endif
#import <CoreMotion/CoreMotion.h>
#import "EmotionPickerViewController.h"

@interface UIImage (test)

+ (UIImage *)imageFromText:(NSString *)text size:(CGFloat)size;
+ (UIImage *)imageFromView:(UIView *)view;

@end

@implementation UIImage (test)

+ (UIImage *)imageFromText:(NSString *)text size:(CGFloat)size;
{
    // set the font type and size
    UIFont *font = [UIFont systemFontOfSize:size];
    CGSize imageSize  = [text sizeWithAttributes:@{ NSFontAttributeName : font }];

    // check if UIGraphicsBeginImageContextWithOptions is available (iOS is 4.0+)
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
    
    // optional: add a shadow, to avoid clipping the shadow you should make the context size bigger
    //
    // CGContextRef ctx = UIGraphicsGetCurrentContext();
    // CGContextSetShadowWithColor(ctx, CGSizeMake(1.0, 1.0), 5.0, [[UIColor grayColor] CGColor]);
    
    // draw in context, you can use also drawInRect:withFont:
    [text drawAtPoint:CGPointMake(0.0, 0.0) withAttributes:@{ NSFontAttributeName : font }];
    
    // transfer image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)imageFromView:(UIView *)view withSize:(CGSize)size;
{
    UIGraphicsBeginImageContext(view.bounds.size);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

+ (UIImage *)imageFromView:(UIView *)view
{
    return [UIImage imageFromView:view withSize:view.bounds.size];
}

- (UIImage *)drawImages:(NSArray *)inputImages inRects:(NSArray *)frames;
{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0);
    [self drawInRect:CGRectMake(0.0, 0.0, self.size.width, self.size.height)];
    NSUInteger inputImagesCount = [inputImages count];
    NSUInteger framesCount = [frames count];
    if (inputImagesCount == framesCount) {
        for (int i = 0; i < inputImagesCount; i++) {
            UIImage *inputImage = [inputImages objectAtIndex:i];
            CGRect frame = [[frames objectAtIndex:i] CGRectValue];
            [inputImage drawInRect:frame];
        }
    }
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end

@interface AffdexDemoViewController ()

@property (strong) NSDate *dateOfLastFrame;
@property (strong) NSDate *dateOfLastProcessedFrame;
@property (strong) NSDictionary *entries;
@property (strong) NSEnumerator *entryEnumerator;
@property (strong) NSDictionary *jsonEntry;
@property (strong) NSDictionary *videoEntry;
@property (strong) NSString *jsonFilename;
@property (strong) NSString *mediaFilename;

@property (strong) NSMutableArray *facePointsToDraw;
@property (strong) NSMutableArray *faceRectsToDraw;
@property (strong) NSMutableArray *viewControllers;
#ifdef BROADCAST_VIA_UDP
@property (strong) GCDAsyncUdpSocket *udpSocket;
#endif

@property (strong) NSArray *availableClassifiers; // the array of dictionaries which contain all available classifiers
@property (strong) NSArray *emotions;   // the array of dictionaries of all emotion classifiers
@property (strong) NSArray *expressions; // the array of dictionaries of all expression classifiers
@property (strong) NSArray *emojis; // the array of dictionaries of all emoji classifiers

// AffdexMe supports up to 6 classifers on the screen at a time
@property (strong) NSString *classifier1Name;
@property (strong) NSString *classifier2Name;
@property (strong) NSString *classifier3Name;
@property (strong) NSString *classifier4Name;
@property (strong) NSString *classifier5Name;
@property (strong) NSString *classifier6Name;

@property (strong) CMMotionManager *motionManager;

@property (strong) UIImage *maleImage;
@property (strong) UIImage *femaleImage;
@property (strong) UIImage *maleImageWithGlasses;
@property (strong) UIImage *femaleImageWithGlasses;
@property (strong) UIImage *unknownImageWithGlasses;
@property (assign) CGRect genderRect;
@property (assign) AFDXCameraType cameraToUse;

@property (strong) NSArray *faces;
@property (assign) Emoji dominantEmoji;

@property (assign) BOOL multifaceMode;
@property (strong) ExpressionViewController *dominantEmotionOrExpression;

@end

@implementation AffdexDemoViewController

#pragma mark -
#pragma mark AFDXDetectorDelegate Methods

#ifdef DEMO_MODE
- (void)detectorDidFinishProcessing:(AFDXDetector *)detector;
{
    [self stopDetector];
}
#endif

- (void)enterSingleFaceMode;
{
    self.multifaceMode = FALSE;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    self.classifierHeaderView_compact.alpha = 1.0;
    self.classifierHeaderView_regular.alpha = 1.0;
    [UIView commitAnimations];
}

- (void)enterMultiFaceMode;
{
    self.multifaceMode = TRUE;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    self.classifierHeaderView_compact.alpha = 0.0;
    self.classifierHeaderView_regular.alpha = 0.0;
    [UIView commitAnimations];
}

- (void)processedImageReady:(AFDXDetector *)detector image:(UIImage *)image faces:(NSDictionary *)faces atTime:(NSTimeInterval)time;
{
    self.faces = [faces allValues];
    // determine single or multi face mode
    if (self.faces.count > 1 && self.multifaceMode == FALSE) {
        // multi face mode
        [self enterMultiFaceMode];
    } else if (self.faces.count == 1 && self.multifaceMode == TRUE) {
        // single face mode
        [self enterSingleFaceMode];
    }
    
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
    
    // setup arrays of points and rects
    self.facePointsToDraw = [NSMutableArray new];
    self.faceRectsToDraw = [NSMutableArray new];

    // Handle each metric in the array
    for (AFDXFace *face in [faces allValues])
    {
        NSDictionary *faceData = face.userInfo;
        NSArray *viewControllers = [faceData objectForKey:@"viewControllers"];
        
        __block float classifier1Score = 0.0, classifier2Score = 0.0, classifier3Score = 0.0;
        __block float classifier4Score = 0.0, classifier5Score = 0.0, classifier6Score = 0.0;
        
        [self.facePointsToDraw addObjectsFromArray:face.facePoints];
        [self.faceRectsToDraw addObject:[NSValue valueWithCGRect:face.faceBounds]];

        for (ExpressionViewController *v in viewControllers)
        {
            for (NSArray *a in self.availableClassifiers)
            {
                // get dominant emoji
                self.dominantEmoji = face.emojis.dominantEmoji;
//                self.dominantEmoji = AFDX_EMOJI_SCREAM;
                
                for (NSDictionary *d in a) {
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier1Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier1Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier2Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier2Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier3Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier3Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier4Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier4Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier5Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier5Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                    if ([[d objectForKey:@"name"] isEqualToString:self.classifier6Name])
                    {
                        NSString *scoreName = [d objectForKey:@"score"];
                        classifier6Score = [[face valueForKeyPath:scoreName] floatValue];
                    }
                }
            }

            if ([v.name isEqualToString:self.classifier1Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier1Score;
                });
            }
            else if ([v.name isEqualToString:self.classifier2Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier2Score;
                });
            }
            else if ([v.name isEqualToString:self.classifier3Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier3Score;
                });
            }
            else if ([v.name isEqualToString:self.classifier4Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier4Score;
                });
            }
            else if ([v.name isEqualToString:self.classifier5Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier5Score;
                });
            }
            else if ([v.name isEqualToString:self.classifier6Name])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    v.metric = classifier6Score;
                });
            }

#ifdef BROADCAST_VIA_UDP
            char buffer[7];
            for (NSUInteger i = 0; i < [self.availableClassifiers count]; i++)
            {
                NSDictionary *entry = [self.availableClassifiers objectAtIndex:i];
                NSString *scoreName = [entry objectForKey:@"score"];
                CGFloat score = [[face valueForKey:scoreName] floatValue];
                buffer[i] = (char)(isnan(score) ? 0 : score);
            }
            NSData *d = [NSData dataWithBytes:buffer length:sizeof(buffer)];
            [self.udpSocket sendData:d toHost:MULTICAST_GROUP port:MULTICAST_PORT withTimeout:-1 tag:0];
#endif
        }
    }
};

- (UIImage *)captureSnapshot;
{
    UIImage *result;
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.view drawViewHierarchyInRect:self.view.frame afterScreenUpdates:YES];
    result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (IBAction)cameraButtonTouched:(id)sender;
{
    self.cameraButton_compact.hidden = TRUE;
    self.cameraButton_regular.hidden = TRUE;
    self.cameraSwapButton_compact.hidden = TRUE;
    self.cameraSwapButton_regular.hidden = TRUE;
    UIImage *snap = [self captureSnapshot];
    self.sound = [[SoundEffect alloc] initWithSoundNamed:@"camera-shutter.mp3"];
    [self.sound play];
    self.cameraButton_compact.hidden = FALSE;
    self.cameraButton_regular.hidden = FALSE;
    self.cameraSwapButton_compact.hidden = FALSE;
    self.cameraSwapButton_regular.hidden = FALSE;
    if (nil != snap) {
        UIImageWriteToSavedPhotosAlbum(snap, nil, nil, nil);
    }
}

- (IBAction)cameraSwapButtonTouched:(id)sender;
{
    if (self.cameraToUse == AFDX_CAMERA_FRONT) {
        self.cameraToUse = AFDX_CAMERA_BACK;
    } else {
        self.cameraToUse = AFDX_CAMERA_FRONT;
    }
    
    [self startDetector];
}

- (void)unprocessedImageReady:(AFDXDetector *)detector image:(UIImage *)image atTime:(NSTimeInterval)time;
{
    __block AffdexDemoViewController *weakSelf = self;
    __block UIImage *newImage = image;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AFDXFace *face in self.faces) {
            UIImage *genderImage = nil;
            switch (face.appearance.gender) {
                case AFDX_GENDER_MALE:
                    genderImage = self.maleImage;
                    if (face.appearance.glasses > 50.0) {
                        genderImage = self.maleImageWithGlasses;
                    }
                    break;
                case AFDX_GENDER_FEMALE:
                    genderImage = self.femaleImage;
                    if (face.appearance.glasses > 50.0) {
                        genderImage = self.femaleImageWithGlasses;
                    }
                    break;
                case AFDX_GENDER_UNKNOWN:
                    genderImage = nil;
                    if (face.appearance.glasses > 50.0) {
                        genderImage = self.unknownImageWithGlasses;
                    }
                    break;
            }

            // create array of images and rects to do all drawing at once
            NSMutableArray *imagesArray = [NSMutableArray array];
            NSMutableArray *rectsArray = [NSMutableArray array];
            
            // add dominant emoji
            if (self.dominantEmoji != AFDX_EMOJI_NONE) {
                for (NSDictionary *emojiDictionary in self.emojis) {
                    NSNumber *code = [emojiDictionary objectForKey:@"code"];
                    if (self.dominantEmoji == [code intValue]) {
                        // match!
                        UIImage *emojiImage = [emojiDictionary objectForKey:@"image"];
                        if (nil != emojiImage) {
                            // resize bounds to be relative in size to bounding box
                            CGSize size = emojiImage.size;
                            CGFloat aspectRatio = size.height / size.width;
                            size.width = face.faceBounds.size.height * .33;
                            size.height = size.width * aspectRatio;
                            
                            CGRect rect = CGRectMake(face.faceBounds.origin.x - size.width,
                                                     face.faceBounds.origin.y - size.height / 2,
                                                     size.width,
                                                     size.height);
                            [imagesArray addObject:emojiImage];
                            [rectsArray addObject:[NSValue valueWithCGRect:rect]];
                            break;
                        }
                    }
                }
            }

            if (weakSelf.drawAppearanceIcons) {
                // add gender image
                if (genderImage != nil) {
                    // resize bounds to be relative in size to bounding box
                    CGSize size = genderImage.size;
                    CGFloat aspectRatio = size.height / size.width;
                    size.width = face.faceBounds.size.height * .45;
                    size.height = size.width * aspectRatio;
                    
                    CGRect rect = CGRectMake(face.faceBounds.origin.x - size.width, face.faceBounds.origin.y + (face.faceBounds.size.height) - size.height, size.width, size.height);
                    [imagesArray addObject:genderImage];
                    [rectsArray addObject:[NSValue valueWithCGRect:rect]];
                }

                // add dominant emotion/expression
                if (self.multifaceMode == TRUE) {
                    CGFloat dominantScore = -9999;
                    NSString *dominantName = @"NONAME";
                 
                    // pass through emotions to find the dominant one
                    for (NSDictionary *d in self.emotions) {
                        CGFloat score = [[face valueForKeyPath:[d objectForKey:@"score"]] floatValue];
                        if (score > dominantScore) {
                            dominantScore = score;
                            dominantName = [d objectForKey:@"name"];
                        }
                    }
                        
                    // pass through expressions to find the dominant one
                    for (NSDictionary *d in self.expressions) {
                        CGFloat score = [[face valueForKeyPath:[d objectForKey:@"score"]] floatValue];
                        if (score > dominantScore) {
                            dominantScore = score;
                            dominantName = [d objectForKey:@"name"];
                        }
                    }
                    
                    BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);
                    if (self.dominantEmotionOrExpression == nil) {
                        self.dominantEmotionOrExpression = [[ExpressionViewController alloc] initWithName:dominantName deviceIsPhone:iPhone];
                    }
                    [self.dominantEmotionOrExpression setMetric:dominantScore];
                    self.dominantEmotionOrExpression.expressionLabel.text = dominantName;
                    // resize bounds to be relative in size to bounding box
                    CGSize size = self.dominantEmotionOrExpression.view.bounds.size;
                    CGFloat aspectRatio = size.height / size.width;
                    size.width = face.faceBounds.size.width * 1.0;
                    size.height = size.width * aspectRatio;
                    UIImage *image = [UIImage imageFromView:self.dominantEmotionOrExpression.view];
                    if (self.cameraToUse == AFDX_CAMERA_FRONT) {
                        image = [UIImage imageWithCGImage:image.CGImage
                                                                    scale:image.scale
                                                              orientation:UIImageOrientationUpMirrored];
                    }
                    CGRect rect = CGRectMake(face.faceBounds.origin.x + (face.faceBounds.size.width / 2) - size.width / 2,
                                             face.faceBounds.origin.y + face.faceBounds.size.height,
                                             size.width,
                                             size.height);
                    [imagesArray addObject:image];
                    [rectsArray addObject:[NSValue valueWithCGRect:rect]];
                }
            }
            
            // do drawing here
            newImage = [AFDXDetector imageByDrawingPoints:weakSelf.drawFacePoints ? weakSelf.facePointsToDraw : nil
                                        andRectangles:weakSelf.drawFaceRect ? weakSelf.faceRectsToDraw : nil
                                            andImages:imagesArray
                                           withRadius:1.4
                                      usingPointColor:[UIColor whiteColor]
                                  usingRectangleColor:[UIColor whiteColor]
                                      usingImageRects:rectsArray
                                              onImage:newImage];
        }

        // flip image if the front camera is being used so that the perspective is mirrored.
        if (self.cameraToUse == AFDX_CAMERA_FRONT) {
            UIImage *flippedImage = [UIImage imageWithCGImage:newImage.CGImage
                                                        scale:image.scale
                                                  orientation:UIImageOrientationUpMirrored];
            [weakSelf.imageView setImage:flippedImage];
        } else {
            [weakSelf.imageView setImage:newImage];
        }

    });
    
#ifdef DEMO_MODE
    static NSTimeInterval last = 0;
    const CGFloat timeConstant = 0.0000001;
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:(time - last) * timeConstant]];
    last = time;
#endif
    
    // compute frames per second and show
    NSDate *now = [NSDate date];
    
    if (nil != weakSelf.dateOfLastFrame)
    {
        NSTimeInterval interval = [now timeIntervalSinceDate:weakSelf.dateOfLastFrame];
        
        if (interval > 0)
        {
            float fps = 1.0 / interval;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.fps.text = [NSString stringWithFormat:@"FPS(C): %.1f", fps];
            });
        }
    }
    
    weakSelf.dateOfLastFrame = now;
}

- (void)detector:(AFDXDetector *)detector hasResults:(NSMutableDictionary *)faces forImage:(UIImage *)image atTime:(NSTimeInterval)time;
{
    if (nil == faces)
    {
        [self unprocessedImageReady:detector image:image atTime:time];
    }
    else
    {
        [self processedImageReady:detector image:image faces:faces atTime:time];
    }
}

- (void)detector:(AFDXDetector *)detector didStartDetectingFace:(AFDXFace *)face;
{
    __block AffdexDemoViewController *weakSelf = self;

 dispatch_async(dispatch_get_main_queue(), ^{
     /*
        BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
        
        if (iPhone == TRUE)
        {
            weakSelf.classifier1View_compact.alpha = 1.0;
            weakSelf.classifier2View_compact.alpha = 1.0;
            weakSelf.classifier3View_compact.alpha = 1.0;
            weakSelf.classifier4View_compact.alpha = 1.0;
            weakSelf.classifier5View_compact.alpha = 1.0;
            weakSelf.classifier6View_compact.alpha = 1.0;
        }
        else
        {
            weakSelf.classifier1View_regular.alpha = 1.0;
            weakSelf.classifier2View_regular.alpha = 1.0;
            weakSelf.classifier3View_regular.alpha = 1.0;
            weakSelf.classifier4View_regular.alpha = 1.0;
            weakSelf.classifier5View_regular.alpha = 1.0;
            weakSelf.classifier6View_regular.alpha = 1.0;
        }
        
        [UIView commitAnimations];
        */
        if (weakSelf.viewControllers != nil)
        {
            face.userInfo = @{@"viewControllers" : weakSelf.viewControllers};

#ifdef BROADCAST_VIA_UDP
            char buffer[2];
            buffer[0] = (char)face.faceId;
            buffer[1] = 1;
            NSData *d = [NSData dataWithBytes:buffer length:sizeof(buffer)];
            [weakSelf.udpSocket sendData:d toHost:MULTICAST_GROUP port:MULTICAST_PORT withTimeout:-1 tag:0];
#endif
        }
    });
}

- (void)detector:(AFDXDetector *)detector didStopDetectingFace:(AFDXFace *)face;
{
    __block AffdexDemoViewController *weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
/*
        BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
        
        if (iPhone == TRUE)
        {
            weakSelf.classifier1View_compact.alpha = 0.0;
            weakSelf.classifier2View_compact.alpha = 0.0;
            weakSelf.classifier3View_compact.alpha = 0.0;
            weakSelf.classifier4View_compact.alpha = 0.0;
            weakSelf.classifier5View_compact.alpha = 0.0;
            weakSelf.classifier6View_compact.alpha = 0.0;
        }
        else
        {
            weakSelf.classifier1View_regular.alpha = 0.0;
            weakSelf.classifier2View_regular.alpha = 0.0;
            weakSelf.classifier3View_regular.alpha = 0.0;
            weakSelf.classifier4View_regular.alpha = 0.0;
            weakSelf.classifier5View_regular.alpha = 0.0;
            weakSelf.classifier6View_regular.alpha = 0.0;
        }
        
        [UIView commitAnimations];
        */
        face.userInfo = nil;
#ifdef BROADCAST_VIA_UDP
        char buffer[2];
        buffer[0] = (char)face.faceId;
        buffer[1] = 0;
        NSData *d = [NSData dataWithBytes:buffer length:sizeof(buffer)];
        [weakSelf.udpSocket sendData:d toHost:MULTICAST_GROUP port:MULTICAST_PORT withTimeout:-1 tag:0];
#endif
    });
}


#pragma mark -
#pragma mark ViewController Delegate Methods

+ (void)initialize;
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"drawFacePoints" : [NSNumber numberWithBool:YES]}];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"drawAppearanceIcons" : [NSNumber numberWithBool:YES]}];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"allowEmojiSelection" : [NSNumber numberWithBool:YES]}];
}

-(BOOL)canBecomeFirstResponder;
{
    return YES;
}

- (void)dealloc;
{
    self.detector = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForBackground:(id)sender;
{
#ifdef BROADCAST_VIA_UDP
    self.udpSocket = nil;
#endif
    [self stopDetector];
}

- (void)prepareForForeground:(id)sender;
{
    [self startDetector];
#ifdef BROADCAST_VIA_UDP
    dispatch_queue_t q = dispatch_queue_create("udp", 0);
    self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithSocketQueue:q];
#endif
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if (self = [super initWithCoder:aDecoder])
    {
        self.emotions = @[@{@"name" : @"Anger",
                            @"propertyName" : @"anger",
                            @"score": @"emotions.anger",
                            @"image": [UIImage imageNamed:@"Anger.jpg"]
                            },
                          @{@"name" : @"Contempt",
                            @"propertyName" : @"contempt",
                            @"score": @"emotions.contempt",
                            @"image": [UIImage imageNamed:@"Contempt.jpg"]
                            },
                          @{@"name" : @"Disgust",
                            @"propertyName" : @"disgust",
                            @"score": @"emotions.disgust",
                            @"image": [UIImage imageNamed:@"Disgust.jpg"]
                            },
                          @{@"name" : @"Engagement",
                            @"propertyName" : @"engagement",
                            @"score": @"emotions.engagement",
                            @"image": [UIImage imageNamed:@"Engagement.jpg"]
                            },
                          @{@"name" : @"Fear",
                            @"propertyName" : @"fear",
                            @"score": @"emotions.fear",
                            @"image": [UIImage imageNamed:@"Fear.jpg"]
                            },
                          @{@"name" : @"Joy",
                            @"propertyName" : @"joy",
                            @"score": @"emotions.joy",
                            @"image": [UIImage imageNamed:@"Joy.jpg"]
                            },
                          @{@"name" : @"Sadness",
                            @"propertyName" : @"sadness",
                            @"score": @"emotions.sadness",
                            @"image": [UIImage imageNamed:@"Sadness.jpg"]
                            },
                          @{@"name" : @"Surprise",
                            @"propertyName" : @"surprise",
                            @"score": @"emotions.surprise",
                            @"image": [UIImage imageNamed:@"Surprise.jpg"]
                            },
                          @{@"name" : @"Valence",
                            @"propertyName" : @"valence",
                            @"score": @"emotions.valence",
                            @"image": [UIImage imageNamed:@"Valence.jpg"]
                            }
                          ];
        
        self.expressions = @[@{@"name" : @"Attention",
                               @"propertyName" : @"attention",
                               @"score": @"attentionScore",
                               @"image": [UIImage imageNamed:@"Attention.jpg"]
                               },
                             @{@"name" : @"Brow Furrow",
                               @"propertyName" : @"browFurrow",
                               @"score": @"browFurrowScore",
                               @"image": [UIImage imageNamed:@"Brow Furrow.jpg"]
                               },
                             @{@"name" : @"Brow Raise",
                               @"propertyName" : @"browRaise",
                               @"score": @"browRaiseScore",
                               @"image": [UIImage imageNamed:@"Brow Raise.jpg"]
                               },
                             @{@"name" : @"Chin Raise",
                               @"propertyName" : @"chinRaise",
                               @"score": @"chinRaiseScore",
                               @"image": [UIImage imageNamed:@"Chin Raise.jpg"]
                               },
                             @{@"name" : @"Eye Closure",
                               @"propertyName" : @"eyeClosure",
                               @"score": @"eyeClosureScore",
                               @"image": [UIImage imageNamed:@"Eye Closure.jpg"]
                               },
                             @{@"name" : @"Inner Brow Raise",
                               @"propertyName" : @"innerBrowRaise",
                               @"score": @"innerBrowRaiseScore",
                               @"image": [UIImage imageNamed:@"Inner Brow Raise.jpg"]
                               },
                             @{@"name" : @"Frown",
                               @"propertyName" : @"lipCornerDepressor",
                               @"score": @"lipCornerDepressorScore",
                               @"image": [UIImage imageNamed:@"Frown.jpg"]
                               },
                             @{@"name" : @"Lip Press",
                               @"propertyName" : @"lipPress",
                               @"score": @"lipPressScore",
                               @"image": [UIImage imageNamed:@"Lip Press.jpg"]
                               },
                             @{@"name" : @"Lip Pucker",
                               @"propertyName" : @"lipPucker",
                               @"score": @"lipPuckerScore",
                               @"image": [UIImage imageNamed:@"Lip Pucker.jpg"]
                               },
                             @{@"name" : @"Lip Suck",
                               @"propertyName" : @"lipSuck",
                               @"score": @"lipSuckScore",
                               @"image": [UIImage imageNamed:@"Lip Suck.jpg"]
                               },
                             @{@"name" : @"Mouth Open",
                               @"propertyName" : @"mouthOpen",
                               @"score": @"mouthOpenScore",
                               @"image": [UIImage imageNamed:@"Mouth Open.jpg"]
                               },
                             @{@"name" : @"Nose Wrinkle",
                               @"propertyName" : @"noseWrinkle",
                               @"score": @"noseWrinkleScore",
                               @"image": [UIImage imageNamed:@"Nose Wrinkle.jpg"]
                               },
                             @{@"name" : @"Smile",
                               @"propertyName" : @"smile",
                               @"score": @"smileScore",
                               @"image": [UIImage imageNamed:@"Smile.jpg"]
                               },
                             @{@"name" : @"Smirk",
                               @"propertyName" : @"smirk",
                               @"score": @"smirkScore",
                               @"image": [UIImage imageNamed:@"Smirk.jpg"]
                               },
                             @{@"name" : @"Upper Lip Raise",
                               @"propertyName" : @"upperLipRaise",
                               @"score": @"upperLipRaiseScore",
                               @"image": [UIImage imageNamed:@"Upper Lip Raise.jpg"]
                               }
                          ];
        
        CGFloat emojiFontSize = 80.0;
        
        self.emojis = @[@{@"name" : @"Laughing",
                          @"score": @"emojis.laughing",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x81" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_LAUGHING]
                          },
                        @{@"name" : @"Smiley",
                          @"score": @"emojis.smiley",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x83" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_SMILEY]
                          },
                        @{@"name" : @"Relaxed",
                          @"score": @"emojis.relaxed",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x8C" size:emojiFontSize],
                          },
                        @{@"name" : @"Wink",
                          @"score": @"emojis.wink",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x89" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_WINK]
                          },
                        @{@"name" : @"Kiss",
                          @"score": @"emojis.kissing",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x97" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_KISSING]
                          },
                        @{@"name" : @"Kiss Eye Closure",
                          @"score": @"emojis.kissingClosedEyes",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x9A" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_KISSING_CLOSED_EYES]
                          },
                        @{@"name" : @"Tongue Wink",
                          @"score": @"emojis.stuckOutTongueWinkingEye",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x9C" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_STUCK_OUT_TONGUE_WINKING_EYE]
                          },
                        @{@"name" : @"Tongue Out",
                          @"score": @"emojis.stuckOutTongue",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x9B" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_STUCK_OUT_TONGUE]
                          },
                        @{@"name" : @"Tongue Eye Closure",
                          @"score": @"emojis.stuckOutTongueClosedEyes",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x9D" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_STUCK_OUT_TONGUE_CLOSED_EYES]
                          },
                        @{@"name" : @"Flushed",
                          @"score": @"emojis.flushed",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\xB3" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_FLUSHED]
                          },
                        @{@"name" : @"Disappointed",
                          @"score": @"emojis.disappointed",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x9E" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_DISAPPOINTED]
                          },
                        @{@"name" : @"Rage",
                          @"score": @"emojis.rage",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\xA0" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_RAGE]
                          },
                        @{@"name" : @"Scream",
                          @"score": @"emojis.scream",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\xB1" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_SCREAM]
                          },
                        @{@"name" : @"Smirk",
                          @"score": @"emojis.smirk",
                          @"image": [UIImage imageFromText:@"\xF0\x9F\x98\x8F" size:emojiFontSize],
                          @"code": [NSNumber numberWithInt:AFDX_EMOJI_SMIRK]
                          }
                        ];
        
        self.availableClassifiers = @[self.emotions, self.expressions, self.emojis];
        
        self.selectedClassifiers = [[[NSUserDefaults standardUserDefaults] objectForKey:@"selectedClassifiers"] mutableCopy];
        if (self.selectedClassifiers == nil)
        {
            self.selectedClassifiers = [NSMutableArray arrayWithObjects:@"Anger", @"Contempt", @"Disgust", @"Fear", @"Joy", @"Sadness", @"Surprise", @"Valence", nil];
        }
    }
    
    return self;
}


- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    self.cameraToUse = AFDX_CAMERA_FRONT;
    self.dominantEmoji = AFDX_EMOJI_NONE;
    
    CGFloat scaleFactor = 4;
    BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);
    if (iPhone == TRUE) {
        scaleFactor *= 1;
    }
    
    self.maleImage = [UIImage imageNamed:@"male-green-noglasses-alpha.png"];
    self.maleImage = [UIImage imageWithCGImage:[self.maleImage CGImage]
                        scale:(self.maleImage.scale * scaleFactor)
                  orientation:(self.maleImage.imageOrientation)];
    self.femaleImage = [UIImage imageNamed:@"female-red-noglasses-alpha.png"];
    self.femaleImage = [UIImage imageWithCGImage:[self.femaleImage CGImage]
                                         scale:(self.femaleImage.scale * scaleFactor)
                                   orientation:(self.femaleImage.imageOrientation)];
    self.maleImageWithGlasses = [UIImage imageNamed:@"male-green-glasses-alpha.png"];
    self.maleImageWithGlasses = [UIImage imageWithCGImage:[self.maleImageWithGlasses CGImage]
                                         scale:(self.maleImageWithGlasses.scale * scaleFactor)
                                   orientation:(self.maleImageWithGlasses.imageOrientation)];
    self.femaleImageWithGlasses = [UIImage imageNamed:@"female-red-glasses-alpha.png"];
    self.femaleImageWithGlasses = [UIImage imageWithCGImage:[self.femaleImageWithGlasses CGImage]
                                                    scale:(self.femaleImageWithGlasses.scale * scaleFactor)
                                              orientation:(self.femaleImageWithGlasses.imageOrientation)];
    self.unknownImageWithGlasses = [UIImage imageNamed:@"unknown-glasses-alpha.png"];
    self.unknownImageWithGlasses = [UIImage imageWithCGImage:[self.unknownImageWithGlasses CGImage]
                                                      scale:(self.unknownImageWithGlasses.scale * scaleFactor)
                                                orientation:(self.unknownImageWithGlasses.imageOrientation)];
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *shortVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    self.versionLabel.text = [NSString stringWithFormat:@"%@ (%@)", shortVersion, version];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(prepareForBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(prepareForForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated;
{
    [self resignFirstResponder];
    
    [super viewWillDisappear:animated];
    
    [self stopDetector];

    for (ExpressionViewController *vc in self.viewControllers)
    {
        [vc.view removeFromSuperview];
    }
    
    self.viewControllers = nil;
}

- (void)viewWillAppear:(BOOL)animated;
{
    self.versionLabel.hidden = TRUE;
    [self.imageView setImage:nil];
    
    NSUInteger count = [self.selectedClassifiers count];
    self.classifier1Name = count >= 1 ? [self.selectedClassifiers objectAtIndex:0] : nil;
    self.classifier2Name = count >= 2 ? [self.selectedClassifiers objectAtIndex:1] : nil;
    self.classifier3Name = count >= 3 ? [self.selectedClassifiers objectAtIndex:2] : nil;
    self.classifier4Name = count >= 4 ? [self.selectedClassifiers objectAtIndex:3] : nil;
    self.classifier5Name = count >= 5 ? [self.selectedClassifiers objectAtIndex:4] : nil;
    self.classifier6Name = count >= 6 ? [self.selectedClassifiers objectAtIndex:5] : nil;
    
    BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);

    [super viewWillAppear:animated];
    
    // setup views
    if (iPhone == TRUE)
    {
        [self.classifier1View_compact setBackgroundColor:[UIColor clearColor]];
        [self.classifier2View_compact setBackgroundColor:[UIColor clearColor]];
        [self.classifier3View_compact setBackgroundColor:[UIColor clearColor]];
        [self.classifier4View_compact setBackgroundColor:[UIColor clearColor]];
        [self.classifier5View_compact setBackgroundColor:[UIColor clearColor]];
        [self.classifier6View_compact setBackgroundColor:[UIColor clearColor]];

        self.classifier1View_compact.alpha = 1.0;
        self.classifier2View_compact.alpha = 1.0;
        self.classifier3View_compact.alpha = 1.0;
        self.classifier4View_compact.alpha = 1.0;
        self.classifier5View_compact.alpha = 1.0;
        self.classifier6View_compact.alpha = 1.0;
    }
    else
    {
        [self.classifier1View_regular setBackgroundColor:[UIColor clearColor]];
        [self.classifier2View_regular setBackgroundColor:[UIColor clearColor]];
        [self.classifier3View_regular setBackgroundColor:[UIColor clearColor]];
        [self.classifier4View_regular setBackgroundColor:[UIColor clearColor]];
        [self.classifier5View_regular setBackgroundColor:[UIColor clearColor]];
        [self.classifier6View_regular setBackgroundColor:[UIColor clearColor]];

        self.classifier1View_regular.alpha = 1.0;
        self.classifier2View_regular.alpha = 1.0;
        self.classifier3View_regular.alpha = 1.0;
        self.classifier4View_regular.alpha = 1.0;
        self.classifier5View_regular.alpha = 1.0;
        self.classifier6View_regular.alpha = 1.0;
    }
    
    // create the expression view controllers to hold the expressions for this face

    self.viewControllers = [NSMutableArray new];
    if (self.classifier1Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier1Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier1View_compact addSubview:vc.view] : [self.classifier1View_regular addSubview:vc.view];
    }

    if (self.classifier2Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier2Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier2View_compact addSubview:vc.view] : [self.classifier2View_regular addSubview:vc.view];
    }
    
    if (self.classifier3Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier3Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier3View_compact addSubview:vc.view] : [self.classifier3View_regular addSubview:vc.view];
    }

    if (self.classifier4Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier4Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier4View_compact addSubview:vc.view] : [self.classifier4View_regular addSubview:vc.view];
    }
    
    if (self.classifier5Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier5Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier5View_compact addSubview:vc.view] : [self.classifier5View_regular addSubview:vc.view];
    }

    if (self.classifier6Name != nil)
    {
        ExpressionViewController *vc = [[ExpressionViewController alloc] initWithName:self.classifier6Name deviceIsPhone:iPhone];
        [self.viewControllers addObject:vc];
        iPhone == TRUE ? [self.classifier6View_compact addSubview:vc.view] : [self.classifier6View_regular addSubview:vc.view];
    }
    
    
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedClassifiers forKey:@"selectedClassifiers"];
    
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event;
{
    if (event.subtype == UIEventSubtypeMotionShake)
    {
        self.versionLabel.hidden = !self.versionLabel.hidden;
    }
    
    [super motionEnded:motion withEvent:event];
}

- (void)viewDidAppear:(BOOL)animated;
{
    [super viewDidAppear:animated];
    [self becomeFirstResponder];

#ifdef DEMO_MODE
//    self.mediaFilename = [[NSBundle mainBundle] pathForResource:@"face1" ofType:@"m4v"];
    self.mediaFilename = [[NSBundle mainBundle] pathForResource:@"faces_in_out" ofType:@"mp4"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.mediaFilename] == YES)
    {
        [self startDetector];
    }
#else
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(status == AVAuthorizationStatusAuthorized) {
        // authorized
        [self startDetector];
    } else if(status == AVAuthorizationStatusDenied){
        // denied
        [[[UIAlertView alloc] initWithTitle:@"Error!"
                                    message:@"AffdexMe doesn't have permission to use camera, please change privacy settings"
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    } else if(status == AVAuthorizationStatusRestricted){
        // restricted
    } else if(status == AVAuthorizationStatusNotDetermined){
        // not determined
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if(granted){
                [self startDetector];
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Error!"
                                            message:@"AffdexMe doesn't have permission to use camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
            }
        }];
    }
#endif
}

#if 0
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;
{
    [UIView setAnimationsEnabled:NO];
    
    if (nil != self.session)
    {
        [self recordOrientation:toInterfaceOrientation];
    }
    
    if (nil != self.selfieView)
    {
        [self setupSelfieView];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;
{
    [UIView setAnimationsEnabled:YES];
    [self.player.view setFrame:self.movieView.bounds];  // player's frame must match parent's
}
#endif

- (void)stopDetector;
{
    [self.detector stop];
}

- (void)startDetector;
{
    [self.detector stop];
    
#ifdef DEMO_MODE
    // create our detector with our desired facial expresions, using the front facing camera
    self.detector = [[AFDXDetector alloc] initWithDelegate:self usingFile:self.mediaFilename maximumFaces:3];
#else
    // create our detector with our desired facial expresions, using the front facing camera
    self.detector = [[AFDXDetector alloc] initWithDelegate:self usingCamera:self.cameraToUse maximumFaces:3];
#endif
    

    self.drawFacePoints = [[[NSUserDefaults standardUserDefaults] objectForKey:@"drawFacePoints"] boolValue];
    self.drawFaceRect = self.drawFacePoints;
    self.drawAppearanceIcons = [[[NSUserDefaults standardUserDefaults] objectForKey:@"drawAppearanceIcons"] boolValue];
    
    NSInteger maxProcessRate = [[[NSUserDefaults standardUserDefaults] objectForKey:@"maxProcessRate"] integerValue];
    if (0 == maxProcessRate)
    {
        maxProcessRate = 5;
    }
    
    if ([[[UIDeviceHardware new] platformString] isEqualToString:@"iPhone 4S"])
    {
        maxProcessRate = 4;
    }
    
    self.detector.maxProcessRate = maxProcessRate;
    
    self.dateOfLastFrame = nil;
    self.dateOfLastProcessedFrame = nil;
    self.detector.licensePath = [[NSBundle mainBundle] pathForResource:@"sdk" ofType:@"license"];
    
    // tell the detector which facial expressions we want to measure
    [self.detector setDetectAllEmotions:NO];
    [self.detector setDetectAllExpressions:NO];
    [self.detector setDetectEmojis:YES];
    self.detector.gender = TRUE;
    self.detector.glasses = TRUE;
    
    for (NSString *s in self.selectedClassifiers)
    {
        for (NSArray *a in self.availableClassifiers)
        {
            for (NSDictionary *d in a) {
                if ([s isEqualToString:[d objectForKey:@"name"]])
                {
                    NSString *pn = [d objectForKey:@"propertyName"];
                    if (nil != pn) {
                        [self.detector setValue:[NSNumber numberWithBool:YES] forKey:pn];
                    } else {
                        [self.detector setDetectEmojis:YES];
                    }
                    break;
                }
            }
        }
    }
    
    // let's start it up!
    NSError *error = [self.detector start];
    
    if (nil != error)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Detector Error" message:[error localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alert show];
        
        return;
    }
    
#ifdef BROADCAST_VIA_UDP
    dispatch_queue_t q = dispatch_queue_create("udp", 0);
    self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithSocketQueue:q];
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)addSubView:(UIView *)highlightView withFrame:(CGRect)frame
{
    highlightView.frame = frame;
    highlightView.layer.borderWidth = 1;
    highlightView.layer.borderColor = [[UIColor whiteColor] CGColor];
    [self.imageView addSubview:highlightView];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations;
{
    NSUInteger result;
    
    result = UIInterfaceOrientationMaskAll;
    
    return result;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender;
{
    EmotionPickerViewController *vc = segue.destinationViewController;
    vc.selectedClassifiers = self.selectedClassifiers;
    vc.availableClassifiers = self.availableClassifiers;
}

- (IBAction)showPicker:(id)sender;
{
    [self performSegueWithIdentifier:@"select" sender:self];
}

@end
