#import <Foundation/Foundation.h>

@interface PAStream : NSObject
{
  const pa_ext_stream_restore_info *info;
}

- (id)initWithValue:(NSValue *)value;

- (NString *)name;
- (NString *)visibleNameForClients:(NSArray *)clientList;

- (NSArray *)volumes;
- (void)setVolume:(NSArray *)volumes;

- (CGFloat)balance;
- (void)setBalance:(CGFloat)bal;

- (BOOL)isMute;
- (void)setIsMute:(BOOL);

@end
