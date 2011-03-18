//
//  BansheeListenerAppDelegate.h
//  BansheeListener
//
//  Created by Henry Lowengard on 3/17/11.
//  Copyright 2011 www.jhhl.net. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BansheeListenerViewController;

@interface BansheeListenerAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet BansheeListenerViewController *viewController;

@end
