#import "ReactNativeMlkitDigitalInk.h"

#import "ReactNativeMlkitDigitalInk-Swift.h"

using namespace facebook::react;

/**
 * Codegen's generated `JS::NativeReactNativeMlkitDigitalInk::NativeXxx`
 * structs (declared in the generated spec header) wrap an `NSDictionary`
 * and expose typed C++ accessor methods — they are not visible to Swift.
 * These helpers flatten them into plain `NSDictionary`/`NSArray` so
 * `DigitalInkRecognizerModuleImpl` (Swift) never has to deal with
 * codegen's C++ types directly.
 */
static NSDictionary *DictFromPoint(const JS::NativeReactNativeMlkitDigitalInk::NativePoint &point)
{
  return @{@"x" : @(point.x()), @"y" : @(point.y()), @"t" : @(point.t())};
}

static NSArray<NSDictionary *> *ArrayFromPoints(
    const facebook::react::LazyVector<JS::NativeReactNativeMlkitDigitalInk::NativePoint> &points)
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  for (const auto &point : points) {
    [result addObject:DictFromPoint(point)];
  }
  return result;
}

static NSDictionary *DictFromStroke(const JS::NativeReactNativeMlkitDigitalInk::NativeStroke &stroke)
{
  return @{@"points" : ArrayFromPoints(stroke.points())};
}

static NSDictionary *DictFromInk(JS::NativeReactNativeMlkitDigitalInk::NativeInk &ink)
{
  NSMutableArray<NSDictionary *> *strokes = [NSMutableArray array];
  for (const auto &stroke : ink.strokes()) {
    [strokes addObject:DictFromStroke(stroke)];
  }
  return @{@"strokes" : strokes};
}

static NSDictionary *DictFromConfig(JS::NativeReactNativeMlkitDigitalInk::NativeRecognizerConfig &config)
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"kind"] = config.kind();
  NSString *languageTag = config.languageTag();
  if (languageTag != nil) {
    dict[@"languageTag"] = languageTag;
  }
  NSString *modelId = config.modelId();
  if (modelId != nil) {
    dict[@"modelId"] = modelId;
  }
  return dict;
}

static NSDictionary *DictFromTensorSpec(const JS::NativeReactNativeMlkitDigitalInk::NativeCustomModelTensorSpec &spec)
{
  NSMutableArray<NSNumber *> *inputShape = [NSMutableArray array];
  for (double d : spec.inputShape()) {
    [inputShape addObject:@(d)];
  }
  NSMutableArray<NSNumber *> *outputShape = [NSMutableArray array];
  for (double d : spec.outputShape()) {
    [outputShape addObject:@(d)];
  }

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"inputShape"] = inputShape;
  dict[@"outputShape"] = outputShape;
  dict[@"preprocessing"] = spec.preprocessing();

  auto labels = spec.labels();
  if (labels.has_value()) {
    NSMutableArray<NSString *> *labelsArray = [NSMutableArray array];
    for (NSString *label : labels.value()) {
      [labelsArray addObject:label];
    }
    dict[@"labels"] = labelsArray;
  }

  auto normalizePoints = spec.normalizePoints();
  if (normalizePoints.has_value()) {
    dict[@"normalizePoints"] = @(normalizePoints.value());
  }

  return dict;
}

static NSDictionary *DictFromRegistration(JS::NativeReactNativeMlkitDigitalInk::NativeCustomModelRegistration &registration)
{
  return @{
    @"modelId" : registration.modelId(),
    @"modelPath" : registration.modelPath(),
    @"tensorSpec" : DictFromTensorSpec(registration.tensorSpec()),
  };
}

@implementation RNDigitalInkRecognizerModule {
  DigitalInkRecognizerModuleImpl *_impl;
}

- (instancetype)init
{
  if (self = [super init]) {
    _impl = [[DigitalInkRecognizerModuleImpl alloc] init];
  }
  return self;
}

- (void)listAvailableModels:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl listAvailableModels:resolve reject:reject];
}

- (void)isModelDownloaded:(NSString *)languageTag
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject
{
  [_impl isModelDownloaded:languageTag resolve:resolve reject:reject];
}

- (void)downloadModel:(NSString *)languageTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl downloadModel:languageTag resolve:resolve reject:reject];
}

- (void)deleteModel:(NSString *)languageTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl deleteModel:languageTag resolve:resolve reject:reject];
}

- (void)registerCustomModel:(JS::NativeReactNativeMlkitDigitalInk::NativeCustomModelRegistration &)registration
                     resolve:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject
{
  [_impl registerCustomModel:DictFromRegistration(registration) resolve:resolve reject:reject];
}

- (void)unregisterCustomModel:(NSString *)modelId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl unregisterCustomModel:modelId resolve:resolve reject:reject];
}

- (void)recognize:(JS::NativeReactNativeMlkitDigitalInk::NativeInk &)ink
            config:(JS::NativeReactNativeMlkitDigitalInk::NativeRecognizerConfig &)config
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  [_impl recognize:DictFromInk(ink) config:DictFromConfig(config) resolve:resolve reject:reject];
}

- (void)clearCanvas:(double)viewTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl clearCanvas:@(viewTag) resolve:resolve reject:reject];
}

- (void)undoLastStroke:(double)viewTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl undoLastStroke:@(viewTag) resolve:resolve reject:reject];
}

- (void)getInk:(double)viewTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_impl getInk:@(viewTag) resolve:resolve reject:reject];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeReactNativeMlkitDigitalInkSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"ReactNativeMlkitDigitalInk";
}

- (void)invalidate
{
  [_impl invalidate];
}

@end
