//
//  SoundEffect.h
//  AffdexMe
//
//  Created by boisy on 8/28/15.
//  Copyright (c) 2016 Affectiva. All rights reserved.
//

#import <AudioToolbox/AudioServices.h>

@interface SoundEffect : NSObject
{
    SystemSoundID soundID;
}

- (id)initWithSoundNamed:(NSString *)filename;
- (void)play;

@end