//
//  FUPinger.h
//  FUPTAG
//
//  Created by G-Triumphant on 2022/6/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FUPinger : NSObject

/// 是否ping的通
@property (nonatomic, assign) BOOL reachable;

/// 有很小概率ping失败, 设定多少次ping失败认为是断网, 默认2次, 必须 >= 2
@property (nonatomic, assign) NSUInteger failureTimes;

/// ping的频率, 默认1s
@property (nonatomic, assign) NSTimeInterval interval;

/// 是否支持IPv4, 默认全部支持
@property (nonatomic, assign) BOOL supportIPv4;

/// 是否支持IPv6
@property (nonatomic,assign) BOOL supportIPv6;

/// 状态改变回调
@property (nonatomic, copy) void(^networkStatusDidChanged)(void);

/// 初始化
/// @param hostName host
+ (instancetype)simplePingerWithHostName:(NSString *)hostName;

/// 开启ping监测
- (void)startPingNotifier;

/// 关闭ping监测
- (void)stopPingNotifier;

@end

NS_ASSUME_NONNULL_END
