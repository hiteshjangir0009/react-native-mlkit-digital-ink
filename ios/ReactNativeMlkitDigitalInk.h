#import <ReactNativeMlkitDigitalInkSpec/ReactNativeMlkitDigitalInkSpec.h>

// Named differently from the Swift module/pod ("ReactNativeMlkitDigitalInk")
// on purpose: when an Objective-C class in this pod shares the pod's exact
// name, Xcode's `-import-underlying-module` (added automatically because
// this target mixes Swift and Objective-C++) can produce a `-Swift.h`
// header with none of this pod's Swift declarations in it — observed in
// practice, not theoretical. The JS-visible module name is unaffected;
// that's `+moduleName` below, not this class name.
@interface RNDigitalInkRecognizerModule : NSObject <NativeReactNativeMlkitDigitalInkSpec>

@end
