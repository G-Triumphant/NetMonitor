//
//  FUNetMonitorTool.m
//  FUPTAG
//
//  Created by G-Triumphant on 2022/6/9.
//

#import "FUNetMonitorTool.h"

#import "FUPinger.h"

static FUNetMonitorTool *_shareManager = nil;
static dispatch_once_t onceToken;

NSString * const FUReachabilityChangedNotification = @"FUNetReachabilityChangedNotification";

@interface FUNetMonitorTool ()

@property (nonatomic, copy) NSString *host;

@property (nonatomic, strong) FUPinger *pinger;

@end

@implementation FUNetMonitorTool

- (instancetype)init {
    if (self = [super init]) {
        _networkStatus = -1;
        _failureTimes = 2;
        _interval = 1.0;
    }
    return self;
}

+ (instancetype)shareInstance {
    dispatch_once(&onceToken, ^{
        _shareManager = [[self alloc] init];
    });
    return _shareManager;
}

+ (instancetype)defultObsever {
    return [FUNetMonitorTool observerWithHost:@"www.baidu.com"];
}

+ (instancetype)observerWithHost:(NSString *)host {
    KFUNetMonitorTool.host = host;
    return KFUNetMonitorTool;
}

+ (void)destroy {
    onceToken = 0;
    _shareManager = nil;
}

- (void)dealloc {
    [self stopNetMonitor];
}

#pragma mark - function
- (void)startNetMonitor {
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    __weak typeof(self) weakSelf = self;
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [weakSelf networkStatusDidChanged];
    }];
    [self.pinger startPingNotifier];
}

- (void)stopNetMonitor {
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
    [self.pinger stopPingNotifier];
}

- (AFNetworkReachabilityManager *)reachabilityManager {
    AFNetworkReachabilityManager *netWorkManager = [AFNetworkReachabilityManager sharedManager];
    [netWorkManager startMonitoring];
    return netWorkManager;
}

- (void)netWorkStateMonitNetWorkStateBlock:(void(^)(AFNetworkReachabilityStatus netStatus))block {
    [[self reachabilityManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (status == AFNetworkReachabilityStatusUnknown || status == AFNetworkReachabilityStatusNotReachable) {
            // ???????????????
        }
        block(status);
    }];
}

#pragma mark - delegate

- (void)networkStatusDidChanged {
    // ???????????????????????????????????????, BOOL???
    BOOL reachable = [[AFNetworkReachabilityManager sharedManager] isReachable];
    BOOL pingReachable = self.pinger.reachable;
     
    // ??????????????????, ????????????:Reachability -> pinger
    if (reachable && pingReachable) {
        // ??????
        self.networkStatus = self.netWorkDetailStatus;
    } else {
        // ??????
        self.networkStatus = FUNetworkStatusNone;
    }
}

#pragma mark - Getter/Setter

- (FUPinger *)pinger {
    if (_pinger == nil) {
        _pinger = [FUPinger simplePingerWithHostName:self.host];
        _pinger.supportIPv4 = self.supportIPv4;
        _pinger.supportIPv6 = self.supportIPv6;
        _pinger.interval = self.interval;
        _pinger.failureTimes = self.failureTimes;
        
        __weak typeof(self) weakSelf = self;
        [_pinger setNetworkStatusDidChanged:^{
            [weakSelf networkStatusDidChanged];
        }];
    }
    return _pinger;
}

- (void)setNetworkStatus:(FUNetworkStatus)networkStatus {
    if (_networkStatus != networkStatus) {
        _networkStatus = networkStatus;
        NSLog(@"????????????-----%@",self.networkDict[@(networkStatus)]);
        if(self.delegate){
            // ????????????
            if ([self.delegate respondsToSelector:@selector(observer:host:networkStatusDidChanged:)]) {
                [self.delegate observer:self host:self.host networkStatusDidChanged:networkStatus];
            }
        }else {
            // ??????????????????
            NSDictionary *info = @{@"status" : @(networkStatus),
                                   @"host"   : self.host
                                   };
            [[NSNotificationCenter defaultCenter] postNotificationName:FUReachabilityChangedNotification object:nil userInfo:info];
        }
    }
}

#pragma mark - tools

- (FUNetworkStatus)netWorkDetailStatus {
    FUNetworkStatus status = FUNetworkStatusNone;
    
    UIApplication *app = [UIApplication sharedApplication];
    id statusBar = nil;
    // ???????????????iOS 13
    if (@available(iOS 13.0, *)) {
        UIStatusBarManager *statusBarManager = [UIApplication sharedApplication].keyWindow.windowScene.statusBarManager;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([statusBarManager respondsToSelector:@selector(createLocalStatusBar)]) {
            UIView *localStatusBar = [statusBarManager performSelector:@selector(createLocalStatusBar)];
            if ([localStatusBar respondsToSelector:@selector(statusBar)]) {
                statusBar = [localStatusBar performSelector:@selector(statusBar)];
            }
        }
#pragma clang diagnostic pop
        if (statusBar) {
            id currentData = [[statusBar valueForKeyPath:@"_statusBar"] valueForKeyPath:@"currentData"];
            id _wifiEntry = [currentData valueForKeyPath:@"wifiEntry"];
            id _cellularEntry = [currentData valueForKeyPath:@"cellularEntry"];
            if (_wifiEntry && [[_wifiEntry valueForKeyPath:@"isEnabled"] boolValue]) {
                status = FUNetworkStatusWifi;
            } else if (_cellularEntry && [[_cellularEntry valueForKeyPath:@"isEnabled"] boolValue]) {
                NSNumber *type = [_cellularEntry valueForKeyPath:@"type"];
                if (type) {
                    switch (type.integerValue) {
                        case 0:
                            status = FUNetworkStatusWifi;
                            break;
                            
                        case 1:
                            status = FUNetworkStatusUnknown;
                            break;
                            
                        case 4:
                            status = FUNetworkStatus3G;
                            break;
                            
                        case 5:
                            status = FUNetworkStatus4G;
                            break;
                            
                        default:
                            status = FUNetworkStatusUnknown;
                            break;
                    }
                }
            }
        }
    }else {
        statusBar = [app valueForKeyPath:@"statusBar"];
        if ([self isPhoneX_Service]) {
                // ?????????
                id statusBarView = [statusBar valueForKeyPath:@"statusBar"];
                UIView *foregroundView = [statusBarView valueForKeyPath:@"foregroundView"];
                NSArray *subviews = [[foregroundView subviews][2] subviews];
                if (subviews.count == 0) {
                    // iOS 12
                    id currentData = [statusBarView valueForKeyPath:@"currentData"];
                    id wifiEntry = [currentData valueForKey:@"wifiEntry"];
                    if ([[wifiEntry valueForKey:@"_enabled"] boolValue]) {
                        status = FUNetworkStatusWifi;
                    }else {
                        // ???1:
                        id cellularEntry = [currentData valueForKey:@"cellularEntry"];
                        // ???2:
                        id secondaryCellularEntry = [currentData valueForKey:@"secondaryCellularEntry"];
                        
                        if (([[cellularEntry valueForKey:@"_enabled"] boolValue]|[[secondaryCellularEntry valueForKey:@"_enabled"] boolValue]) == NO) {
                            // ????????????
                            status = FUNetworkStatusNone;
                        }else {
                            // ?????????1?????????2
                            BOOL isCardOne = [[cellularEntry valueForKey:@"_enabled"] boolValue];
                            int networkType = isCardOne ? [[cellularEntry valueForKey:@"type"] intValue] : [[secondaryCellularEntry valueForKey:@"type"] intValue];
                            switch (networkType) {
                                case 0:
                                    //?????????
                                    status = FUNetworkStatusNone;
                                    break;
        
                                case 3:
                                    status = FUNetworkStatusUnknown;
                                    break;
                                    
                                case 4:
                                    status = FUNetworkStatus3G;
                                    break;
                                    
                                case 5:
                                    status = FUNetworkStatus4G;
                                    break;
                                    
                                default:
                                    break;
                            }
                        }
                    }
                }else {
                    for (id subview in subviews) {
                        if ([subview isKindOfClass:NSClassFromString(@"_UIStatusBarWifiSignalView")]) {
                            status = FUNetworkStatusWifi;
                        }else if ([subview isKindOfClass:NSClassFromString(@"_UIStatusBarStringView")]) {
                            status = FUNetworkStatusWWAN;
                        }
                    }
                }
            }else {
                // ????????????
                UIView *foregroundView = [statusBar valueForKeyPath:@"foregroundView"];
                NSArray *subviews = [foregroundView subviews];
                
                for (id subview in subviews) {
                    if ([subview isKindOfClass:NSClassFromString(@"UIStatusBarDataNetworkItemView")]) {
                        int networkType = [[subview valueForKeyPath:@"dataNetworkType"] intValue];
                        switch (networkType) {
                            case 0:
                                status = FUNetworkStatusNone;
                                break;
                                
                            case 1:
                                status = FUNetworkStatusUnknown;
                                break;
                                
                            case 2:
                                status = FUNetworkStatus3G;
                                break;
                                
                            case 3:
                                status = FUNetworkStatus4G;
                                break;
                                
                            case 5:
                                status = FUNetworkStatusWifi;
                                break;
                                
                            default:
                                break;
                        }
                    }
                }
            }
    }
    return status;
}

- (NSDictionary *)networkDict {
    return @{
             @(FUNetworkStatusNone)   : @"?????????",
             @(FUNetworkStatusUnknown) : @"????????????",
             @(FUNetworkStatus3G)     : @"3G??????",
             @(FUNetworkStatus4G)     : @"4G??????",
             @(FUNetworkStatusWifi)   : @"WIFI??????",
             @(FUNetworkStatusWWAN)   : @"????????????",
            };
}

- (BOOL)isPhoneX_Service {
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeAreaInsets = [UIApplication sharedApplication].windows[0].safeAreaInsets;
        return safeAreaInsets.top == 44.0 || safeAreaInsets.bottom == 44.0 || safeAreaInsets.left == 44.0 || safeAreaInsets.right == 44.0;
    }else {
        return NO;
    }
}

@end
