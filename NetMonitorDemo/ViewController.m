//
//  ViewController.m
//  NetMonitorDemo
//
//  Created by G-Triumphant on 2022/6/9.
//

#import "ViewController.h"

#import "FUNetMonitorTool.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [FUNetMonitorTool defultObsever];
    [KFUNetMonitorTool startNetMonitor];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChanged:) name:FUReachabilityChangedNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FUReachabilityChangedNotification object:nil];
}

- (void)networkStatusChanged:(NSNotification *)notify {
    NSLog(@"notify-------%@", notify.userInfo);
}


@end
