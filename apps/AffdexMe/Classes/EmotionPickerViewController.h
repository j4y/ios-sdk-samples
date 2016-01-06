//
//  EmotionPickerViewController.h
//  AffdexMe
//
//  Created by boisy on 8/18/15.
//  Copyright (c) 2016 Affectiva. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface EmotionVideoCell : UICollectionViewCell

@property (strong) MPMoviePlayerController *moviePlayer;
@property (strong) IBOutlet UIImageView *classifierView;
@property (weak) IBOutlet UILabel *label;

@end

@interface EmotionPickerViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak) IBOutlet UICollectionView *collectionViewRegular;
@property (weak) IBOutlet UICollectionView *collectionViewCompact;
@property (strong) NSArray *availableClassifiers;
@property (strong) NSMutableArray *selectedClassifiers;
@property (weak) IBOutlet UILabel *instructionLabelRegular;
@property (weak) IBOutlet UILabel *instructionLabelCompact;

- (IBAction)clearAllTouched:(id)sender;
- (IBAction)doneTouched:(id)sender;

@end
