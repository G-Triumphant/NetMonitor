//
//  FUPinger.m
//  FUPTAG
//
//  Created by G-Triumphant on 2022/6/9.
//

#import "FUPinger.h"

#import "SimplePing.h"
#include <netdb.h>

@interface FUPinger ()<SimplePingDelegate>

@property (nonatomic, strong) SimplePing *pinger;

@property (nonatomic, copy) NSString *hostName;

@property (nonatomic, strong) NSTimer *sendTimer;

@property (nonatomic, strong) NSMutableArray *failureRecords;

@end

@implementation FUPinger

- (instancetype)init {
    if (self = [super init]) {
        self.interval = 1.0;
        self.failureTimes = 2;
        self.reachable = YES;
    }
    return self;
}

+ (instancetype)simplePingerWithHostName:(NSString *)hostName {
    FUPinger *pinger = [[FUPinger alloc] init];
    pinger.hostName = hostName;
    return pinger;
}

- (void)dealloc {
    [self stopPingNotifier];
    [self.failureRecords removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendPing) object:nil];
}

#pragma mark - function

- (void)startPingNotifier {
    [self startForceIPv4:self.supportIPv4 forceIPv6:self.supportIPv6];
}

- (void)stopPingNotifier {
    [self.pinger stop];
    self.pinger.delegate = nil;
    self.pinger = nil;

    [self.sendTimer invalidate];
    self.sendTimer = nil;
}

- (void)startForceIPv4:(BOOL)forceIPv4 forceIPv6:(BOOL)forceIPv6 {
    self.pinger = [[SimplePing alloc] initWithHostName:self.hostName];
    if (forceIPv4 && !forceIPv6) {
        self.pinger.addressStyle = SimplePingAddressStyleICMPv4;
    }else if (forceIPv6 && !forceIPv4){
        self.pinger.addressStyle = SimplePingAddressStyleICMPv6;
    }else{
        self.pinger.addressStyle = SimplePingAddressStyleAny;
    }
    
    self.pinger.delegate = self;
    
    [self.pinger start];
}

- (void)sendPing{
    [self.pinger sendPingWithData:nil];
}

#pragma mark - SimplePingDelegate

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    NSLog(@"didStartPingWithAddress: %@",[self addressWithData:address]);
    
    [self sendPing];
    
    if (!_sendTimer) {
        _sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
    }
}

// ????????????, sequenceNumber??????:0~65535, ???????????????0??????
- (void)simplsentePing:(SimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
     NSLog(@"#%u sent", sequenceNumber);
    if(sequenceNumber == 0) {
        // ??????
        [self.failureRecords removeAllObjects];
    }
    
    // ??????failuretimes??????????????????
    if (self.failureRecords.count >= self.failureTimes) {
        self.reachable = NO;
        [self.failureRecords removeAllObjects];
    }
    
    // ?????????????????????
    [self.failureRecords addObject:@(sequenceNumber)];
}

// ????????????
- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error {
    NSLog(@"#%u fail sent",sequenceNumber);
    
    // ????????????,??????????????????
    self.reachable = NO;
    [self.failureRecords removeAllObjects];
}

// ????????????
- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    // ??????
    self.reachable = YES;
    [self.failureRecords removeAllObjects];
}

// ????????????, ??????ping
- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
     self.reachable = NO;
    [self stopPingNotifier];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startPingNotifier];
    });
    
}

// ??????data, ??????host
- (NSString *)addressWithData:(NSData *)address {
    char *hostStr = malloc(NI_MAXHOST);
    memset(hostStr, 0, NI_MAXHOST);
    BOOL success = getnameinfo((const struct sockaddr *)address.bytes, (socklen_t)address.length, hostStr, (socklen_t)NI_MAXHOST, nil, 0, NI_NUMERICHOST) == 0;
    NSString *result;
    if (success) {
        result = [NSString stringWithUTF8String:hostStr];
    }else{
        result = @"?";
    }
    free(hostStr);
    return  result;
}

#pragma mark - Getter/Setter

- (void)setReachable:(BOOL)reachable {
    if (_reachable != reachable) {
        _reachable = reachable;
        if (self.networkStatusDidChanged) {
            self.networkStatusDidChanged();
        }
    }
}

- (void)setFailureTimes:(NSUInteger)failureTimes {
    if (failureTimes < 2) {
        failureTimes = 2;
    }
    _failureTimes = failureTimes;
}

- (NSMutableArray *)failureRecords {
    if (!_failureRecords) {
        _failureRecords = [NSMutableArray array];
    }
    return _failureRecords;
}

@end
