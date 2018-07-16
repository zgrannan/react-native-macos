// TODO: What copyright do we use?
#import "RCTPlatform.h"

#import <AppKit/AppKit.h>

#import "RCTUtils.h"

@implementation RCTPlatform

RCT_EXPORT_MODULE(MacOSConstants)

- (NSDictionary<NSString *, id> *)constantsToExport
{
  NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
  return @{
    @"osVersion": [NSString stringWithFormat:@"%ld.%ld.%ld", osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion],
  };
}

@end
