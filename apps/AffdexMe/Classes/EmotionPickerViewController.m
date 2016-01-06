//
//  EmotionPickerViewController.m
//  AffdexMe
//
//  Created by boisy on 8/18/15.
//  Copyright (c) 2016 Affectiva. All rights reserved.
//

#import "EmotionPickerViewController.h"
#if PLAY_SOUNDS
#import "SoundEffect.h"
#endif
#import "HeaderCollectionReusableView.h"
#import "AffdexDemoViewController.h"

#define MAX_CLASSIFIERS_SELECTED        6

#define SELECTED_COLOR [UIColor greenColor]
#define SELECTED_TEXT_COLOR [UIColor blackColor]
#define UNSELECTED_COLOR [UIColor whiteColor]
#define UNSELECTED_TEXT_COLOR [UIColor blackColor]
#define ERROR_COLOR [UIColor redColor]
#define ERROR_TEXT_COLOR [UIColor whiteColor]

@implementation EmotionVideoCell

// Fix for iOS 9 drawing issue with cells
- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)prepareForReuse {
    self.selected = FALSE;
}

- (void)highlight {
    self.label.textColor = SELECTED_TEXT_COLOR;
    self.label.backgroundColor = SELECTED_COLOR;
    self.backgroundColor = SELECTED_COLOR;
}

- (void)unhighlight {
    self.label.textColor = UNSELECTED_TEXT_COLOR;
    self.label.backgroundColor = UNSELECTED_COLOR;
    self.backgroundColor = UNSELECTED_COLOR;
}

- (void)highlightError {
    self.label.textColor = ERROR_TEXT_COLOR;
    self.label.backgroundColor = ERROR_COLOR;
    self.backgroundColor = ERROR_COLOR;
}

@end

@interface EmotionPickerViewController ()

#if PLAY_SOUNDS
@property (strong) SoundEffect *sound;
#endif

@end

@implementation EmotionPickerViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
    }
    
    return self;
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    self.collectionViewCompact.allowsMultipleSelection = TRUE;
    self.collectionViewRegular.allowsMultipleSelection = TRUE;

    UICollectionViewFlowLayout *collectionViewLayout = (UICollectionViewFlowLayout*)self.collectionViewCompact.collectionViewLayout;
    collectionViewLayout.sectionInset = UIEdgeInsetsMake(00, 0, 20, 0);

    collectionViewLayout = (UICollectionViewFlowLayout*)self.collectionViewRegular.collectionViewLayout;
    collectionViewLayout.sectionInset = UIEdgeInsetsMake(00, 0, 20, 0);
}

- (NSString *)getClassifierNameForPath:(NSIndexPath *)path;
{
    NSArray *array = [self.availableClassifiers objectAtIndex:[path indexAtPosition:0]];
    NSDictionary *dictionary = [array objectAtIndex:[path indexAtPosition:1]];
    return [dictionary objectForKey:@"name"];
    
}

- (NSIndexPath *)getPathForClassifierName:(NSString *)name
{
    NSIndexPath *result = nil;
    
    for (int i = 0; i < [self.availableClassifiers count]; i++)
    {
        NSArray *classifiers = [self.availableClassifiers objectAtIndex:i];
        
        for (int j = 0; j < [classifiers count]; j++)
        {
            NSDictionary *d = [classifiers objectAtIndex:j];
            if ([[d objectForKey:@"name"] isEqualToString:name])
            {
                result = [NSIndexPath indexPathForItem:j inSection:i];
                return result;
            }
        }
    }
    
    return result;
}

- (void)viewWillDisappear:(BOOL)animated;
{
    BOOL iPhone = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone);
    UICollectionView *v;
    if (iPhone) {
        v = self.collectionViewCompact;
    } else {
        v = self.collectionViewRegular;
    }
    [self.selectedClassifiers removeAllObjects];
    for (NSIndexPath *path in [v indexPathsForSelectedItems]) {
        [self.selectedClassifiers addObject:[self getClassifierNameForPath:path]];
    }
}

- (void)viewWillAppear:(BOOL)animated;
{
    for (NSString *name in self.selectedClassifiers) {
        NSIndexPath *path = [self getPathForClassifierName:name];
        
        if (nil != path) {
            if ([path indexAtPosition:0] > 1 && [[[NSUserDefaults standardUserDefaults] objectForKey:@"allowEmojiSelection"] boolValue] == NO) {
                break;
            }
            [self.collectionViewCompact selectItemAtIndexPath:path
                                                     animated:YES
                                               scrollPosition:UICollectionViewScrollPositionNone];
            [self.collectionViewCompact scrollToItemAtIndexPath:path
                                               atScrollPosition:UICollectionViewScrollPositionBottom
                                                       animated:NO];
            [self collectionView:self.collectionViewCompact didSelectItemAtIndexPath:path];
            
            [self.collectionViewRegular selectItemAtIndexPath:path
                                                     animated:YES
                                               scrollPosition:UICollectionViewScrollPositionNone];
            [self.collectionViewRegular scrollToItemAtIndexPath:path
                                               atScrollPosition:UICollectionViewScrollPositionBottom
                                                       animated:NO];
            [self collectionView:self.collectionViewRegular didSelectItemAtIndexPath:path];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated;
{
    [super viewDidAppear:animated];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView;
{
    NSInteger count = [self.availableClassifiers count];

    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"allowEmojiSelection"] boolValue] == YES) {
        return count;
    } else {
        return count - 1;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
{
    NSUInteger result;
    
    result = [[self.availableClassifiers objectAtIndex:section] count];
    
    return result;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    EmotionVideoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"EmotionCell" forIndexPath:indexPath];

    if ([collectionView.indexPathsForSelectedItems containsObject:indexPath]) {
        [collectionView selectItemAtIndexPath:indexPath animated:FALSE scrollPosition:UICollectionViewScrollPositionNone];
        [cell highlight];
    } else {
        [cell unhighlight];
    }
    
    NSUInteger section = [indexPath section];
    NSUInteger index = [indexPath row];
    cell.label.text = [[[self.availableClassifiers objectAtIndex:section] objectAtIndex:index] objectForKey:@"name"];
    
    UIImage *image = [[[self.availableClassifiers objectAtIndex:section] objectAtIndex:index] objectForKey:@"image"];
    [cell.classifierView setImage:image];
#if 0
    if (cell.moviePlayer == nil)
    {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"anger" ofType:@"mp4"];
        
        cell.moviePlayer = [[MPMoviePlayerController alloc]
                            initWithContentURL: [NSURL fileURLWithPath:
                                                 filePath]];
        
        CGRect videoFrame = CGRectMake(0, 0, cell.movieView.frame.size.width, cell.movieView.frame.size.height);
        
        [cell.moviePlayer.view setFrame:videoFrame];
        
        cell.moviePlayer.shouldAutoplay = TRUE;
        cell.moviePlayer.repeatMode = TRUE;
        [cell.moviePlayer prepareToPlay];
        [cell.movieView addSubview:cell.moviePlayer.view];
        cell.moviePlayer.view.backgroundColor = [UIColor blueColor];
    }
#endif
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    EmotionVideoCell *cell = (EmotionVideoCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell unhighlight];

    NSUInteger count = [[collectionView indexPathsForSelectedItems] count];
    self.instructionLabelCompact.text = [NSString stringWithFormat:@"%ld classifier%@ selected.",
                                         (unsigned long)count,
                                         count == 1 ? @"" : @"s"];
    self.instructionLabelRegular.text = [NSString stringWithFormat:@"%ld classifier%@ selected.",
                                         (unsigned long)count,
                                         count == 1 ? @"" : @"s"];
#if PLAY_SOUNDS
    self.sound = [[SoundEffect alloc] initWithSoundNamed:@"Whoot.m4a"];
    [self.sound play];
#endif
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    EmotionVideoCell *cell = (EmotionVideoCell *)[collectionView cellForItemAtIndexPath:indexPath];

    NSUInteger count = [[collectionView indexPathsForSelectedItems] count];
    if (count <= MAX_CLASSIFIERS_SELECTED) // && [self.selectedClassifiers containsObject:cell.label.text] == NO)
    {
        [cell highlight];

        self.instructionLabelCompact.text = [NSString stringWithFormat:@"%ld classifier%@ selected.",
                                             (unsigned long)count,
                                             count == 1 ? @"" : @"s"];
        self.instructionLabelRegular.text = [NSString stringWithFormat:@"%ld classifier%@ selected.",
                                             (unsigned long)count,
                                             count == 1 ? @"" : @"s"];
#if PLAY_SOUNDS
        self.sound = [[SoundEffect alloc] initWithSoundNamed:@"Whit.m4a"];
        [self.sound play];
#endif
    }
    else
    {
        if (count >= MAX_CLASSIFIERS_SELECTED)
        {
            // we are at our max.
            [collectionView deselectItemAtIndexPath:indexPath animated:NO];
            self.instructionLabelRegular.text = [NSString stringWithFormat:@"You already have %d classifiers selected.", MAX_CLASSIFIERS_SELECTED];
            self.instructionLabelCompact.text = self.instructionLabelRegular.text;

            // alert user visually
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell highlightError];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [cell unhighlight];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [cell highlightError];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [cell unhighlight];
                        });
                    });
                });
            });
#if PLAY_SOUNDS
            self.sound = [[SoundEffect alloc] initWithSoundNamed:@"Enk.m4a"];
            [self.sound play];
#endif
        }
        else
        {
            switch (count) {
                case 0:
                    self.instructionLabelCompact.text = @"No classifiers selected.";
                    self.instructionLabelRegular.text = self.instructionLabelCompact.text;
                    break;
                    
                case 1:
                    self.instructionLabelCompact.text = @"1 classifies selected.";
                    self.instructionLabelRegular.text = self.instructionLabelCompact.text;
                    break;
                    
                default:
                    self.instructionLabelCompact.text = [NSString stringWithFormat:@"%ld classifiers selected.",
                                                         (unsigned long)count];

                    self.instructionLabelRegular.text = self.instructionLabelCompact.text;
                    break;
            }
#if PLAY_SOUNDS
            self.sound = [[SoundEffect alloc] initWithSoundNamed:@"Whoot.m4a"];
            [self.sound play];
#endif
        }
    }

//    [cell.moviePlayer play];
    
//    [self.collectionViewCompact reloadData];
//    [self.collectionViewRegular reloadData];
}

- (IBAction)clearAllTouched:(id)sender;
{
    NSArray *a = [self.collectionViewCompact indexPathsForSelectedItems];
    
    for (NSIndexPath *p in a) {
        [self.collectionViewCompact deselectItemAtIndexPath:p animated:NO];
        [self.collectionViewCompact reloadData];
    }
    self.instructionLabelCompact.text = @"No classifiers selected.";

    a = [self.collectionViewRegular indexPathsForSelectedItems];
    
    for (NSIndexPath *p in a) {
        [self.collectionViewRegular deselectItemAtIndexPath:p animated:NO];
        [self.collectionViewRegular reloadData];
    }
    self.instructionLabelRegular.text = self.instructionLabelCompact.text;
}

- (IBAction)doneTouched:(id)sender;
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    HeaderCollectionReusableView *reusableview = nil;

    if (kind == UICollectionElementKindSectionHeader)
    {
        HeaderCollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
        if ([indexPath indexAtPosition:0] == 0)
        {
            headerView.label.text = @"Emotions";
        }
        else if ([indexPath indexAtPosition:0] == 1)
        {
            headerView.label.text = @"Expressions";
        }
        else
        {
            headerView.label.text = @"Emojis";
        }
        
        reusableview = headerView;
    }
    
    if (kind == UICollectionElementKindSectionFooter)
    {
//        UICollectionReusableView *footerview = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"FooterView" forIndexPath:indexPath];
        
//        reusableview = footerview;
    }
    
    return reusableview;
}

@end
