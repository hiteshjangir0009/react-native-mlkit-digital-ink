#import "DigitalInkCanvasViewComponentView.h"

// Needed before "ReactNativeMlkitDigitalInk-Swift.h" below: that generated
// header declares DigitalInkRecognizerModuleImpl's interface, whose method
// signatures reference RCTPromiseResolveBlock/RCTPromiseRejectBlock — this
// file has no other reason to import RCTBridgeModule.h, but without it
// those typedefs aren't visible yet and the Swift header fails to parse.
#import <React/RCTBridgeModule.h>
#import <React/RCTConversions.h>
#import <react/renderer/components/ReactNativeMlkitDigitalInkSpec/ComponentDescriptors.h>
#import <react/renderer/components/ReactNativeMlkitDigitalInkSpec/EventEmitters.h>
#import <react/renderer/components/ReactNativeMlkitDigitalInkSpec/Props.h>
#import <react/renderer/components/ReactNativeMlkitDigitalInkSpec/RCTComponentViewHelpers.h>
#import <react/renderer/components/ReactNativeMlkitDigitalInkSpec/ShadowNodes.h>

#import "ReactNativeMlkitDigitalInk-Swift.h"

using namespace facebook::react;

@interface DigitalInkCanvasViewComponentView () <RCTDigitalInkCanvasViewViewProtocol>
@end

@implementation DigitalInkCanvasViewComponentView {
  DigitalInkCanvasView *_canvasView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _props = DigitalInkCanvasViewShadowNode::defaultSharedProps();

    _canvasView = [[DigitalInkCanvasView alloc] initWithFrame:self.bounds];
    _canvasView.autoresizingMask = (UIViewAutoresizing)(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

    __weak __typeof(self) weakSelf = self;
    _canvasView.onStrokeStart = ^(NSInteger strokeIndex) {
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil || strongSelf->_eventEmitter == nullptr) {
        return;
      }
      std::static_pointer_cast<const DigitalInkCanvasViewEventEmitter>(strongSelf->_eventEmitter)
          ->onStrokeStart(DigitalInkCanvasViewEventEmitter::OnStrokeStart{.strokeIndex = static_cast<int>(strokeIndex)});
    };
    _canvasView.onStrokeEnd = ^(NSInteger strokeIndex, NSInteger pointCount) {
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil || strongSelf->_eventEmitter == nullptr) {
        return;
      }
      std::static_pointer_cast<const DigitalInkCanvasViewEventEmitter>(strongSelf->_eventEmitter)
          ->onStrokeEnd(DigitalInkCanvasViewEventEmitter::OnStrokeEnd{
              .strokeIndex = static_cast<int>(strokeIndex), .pointCount = static_cast<int>(pointCount)});
    };
    _canvasView.onCanvasChange = ^(NSInteger strokeCount) {
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil || strongSelf->_eventEmitter == nullptr) {
        return;
      }
      std::static_pointer_cast<const DigitalInkCanvasViewEventEmitter>(strongSelf->_eventEmitter)
          ->onCanvasChange(DigitalInkCanvasViewEventEmitter::OnCanvasChange{.strokeCount = static_cast<int>(strokeCount)});
    };

    self.contentView = _canvasView;
  }
  return self;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<DigitalInkCanvasViewComponentDescriptor>();
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const DigitalInkCanvasViewProps &>(*_props);
  const auto &newViewProps = static_cast<const DigitalInkCanvasViewProps &>(*props);

  if (oldViewProps.strokeColor != newViewProps.strokeColor) {
    UIColor *color = RCTUIColorFromSharedColor(newViewProps.strokeColor);
    _canvasView.strokeColor = color ?: UIColor.blackColor;
  }

  if (oldViewProps.strokeWidth != newViewProps.strokeWidth) {
    _canvasView.strokeWidth = newViewProps.strokeWidth > 0.0 ? (CGFloat)newViewProps.strokeWidth
                                                              : DigitalInkCanvasView.defaultStrokeWidth;
  }

  if (oldViewProps.maxPointsPerStroke != newViewProps.maxPointsPerStroke) {
    _canvasView.maxPointsPerStroke = newViewProps.maxPointsPerStroke > 0
        ? newViewProps.maxPointsPerStroke
        : DigitalInkCanvasView.defaultMaxPointsPerStroke;
  }

  [super updateProps:props oldProps:oldProps];
}

// The React tag is assigned via this standard UIView property by the
// Fabric mounting layer. Hooking it here is how the view registers itself
// in `DigitalInkCanvasViewRegistry` so the TurboModule's
// `clearCanvas`/`undoLastStroke`/`getInk` methods (which only ever receive
// a numeric tag from JS) can resolve the live view without any private
// Fabric view-resolution API.
- (void)setTag:(NSInteger)tag
{
  NSInteger previousTag = self.tag;
  [super setTag:tag];
  if (previousTag != 0) {
    [DigitalInkCanvasViewRegistry.shared unregisterForTag:previousTag];
  }
  if (tag != 0) {
    [DigitalInkCanvasViewRegistry.shared register:_canvasView forTag:tag];
  }
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  if (self.tag != 0) {
    [DigitalInkCanvasViewRegistry.shared unregisterForTag:self.tag];
  }
  [_canvasView teardown];
}

- (void)dealloc
{
  if (self.tag != 0) {
    [DigitalInkCanvasViewRegistry.shared unregisterForTag:self.tag];
  }
}

@end

Class<RCTComponentViewProtocol> DigitalInkCanvasViewCls(void)
{
  return DigitalInkCanvasViewComponentView.class;
}
