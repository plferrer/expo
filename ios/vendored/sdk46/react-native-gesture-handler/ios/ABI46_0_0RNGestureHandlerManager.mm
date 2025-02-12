#import "ABI46_0_0RNGestureHandlerManager.h"

#import <ABI46_0_0React/ABI46_0_0RCTLog.h>
#import <ABI46_0_0React/ABI46_0_0RCTViewManager.h>
#import <ABI46_0_0React/ABI46_0_0RCTComponent.h>
#import <ABI46_0_0React/ABI46_0_0RCTRootView.h>
#import <ABI46_0_0React/ABI46_0_0RCTUIManager.h>
#import <ABI46_0_0React/ABI46_0_0RCTEventDispatcher.h>

#if __has_include(<ABI46_0_0React/ABI46_0_0RCTRootContentView.h>)
#import <ABI46_0_0React/ABI46_0_0RCTRootContentView.h>
#else
#import "ABI46_0_0RCTRootContentView.h"
#endif

#import "ABI46_0_0RNGestureHandlerActionType.h"
#import "ABI46_0_0RNGestureHandlerState.h"
#import "ABI46_0_0RNGestureHandler.h"
#import "ABI46_0_0RNGestureHandlerRegistry.h"
#import "ABI46_0_0RNRootViewGestureRecognizer.h"

#ifdef ABI46_0_0RN_FABRIC_ENABLED
#import <ABI46_0_0React/ABI46_0_0RCTViewComponentView.h>
#import <ABI46_0_0React/ABI46_0_0RCTSurfaceTouchHandler.h>
#else
#import <ABI46_0_0React/ABI46_0_0RCTTouchHandler.h>
#endif // ABI46_0_0RN_FABRIC_ENABLED

#import "Handlers/ABI46_0_0RNPanHandler.h"
#import "Handlers/ABI46_0_0RNTapHandler.h"
#import "Handlers/ABI46_0_0RNFlingHandler.h"
#import "Handlers/ABI46_0_0RNLongPressHandler.h"
#import "Handlers/ABI46_0_0RNNativeViewHandler.h"
#import "Handlers/ABI46_0_0RNPinchHandler.h"
#import "Handlers/ABI46_0_0RNRotationHandler.h"
#import "Handlers/ABI46_0_0RNForceTouchHandler.h"
#import "Handlers/ABI46_0_0RNManualHandler.h"

// We use the method below instead of ABI46_0_0RCTLog because we log out messages after the bridge gets
// turned down in some cases. Which normally with ABI46_0_0RCTLog would cause a crash in DEBUG mode
#define ABI46_0_0RCTLifecycleLog(...) ABI46_0_0RCTDefaultLogFunction(ABI46_0_0RCTLogLevelInfo, ABI46_0_0RCTLogSourceNative, @(__FILE__), @(__LINE__), [NSString stringWithFormat:__VA_ARGS__])

@interface ABI46_0_0RNGestureHandlerManager () <ABI46_0_0RNGestureHandlerEventEmitter, ABI46_0_0RNRootViewGestureRecognizerDelegate>

@end

@implementation ABI46_0_0RNGestureHandlerManager
{
    ABI46_0_0RNGestureHandlerRegistry *_registry;
    ABI46_0_0RCTUIManager *_uiManager;
    NSHashTable<ABI46_0_0RNRootViewGestureRecognizer *> *_rootViewGestureRecognizers;
    ABI46_0_0RCTEventDispatcher *_eventDispatcher;
    id _reanimatedModule;
}

- (instancetype)initWithUIManager:(ABI46_0_0RCTUIManager *)uiManager
                  eventDispatcher:(ABI46_0_0RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        _uiManager = uiManager;
        _eventDispatcher = eventDispatcher;
        _registry = [ABI46_0_0RNGestureHandlerRegistry new];
        _rootViewGestureRecognizers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        _reanimatedModule = nil;
    }
    return self;
}

- (void)createGestureHandler:(NSString *)handlerName
                         tag:(NSNumber *)handlerTag
                      config:(NSDictionary *)config
{
    static NSDictionary *map;
    static dispatch_once_t mapToken;
    dispatch_once(&mapToken, ^{
        map = @{
                @"PanGestureHandler" : [ABI46_0_0RNPanGestureHandler class],
                @"TapGestureHandler" : [ABI46_0_0RNTapGestureHandler class],
                @"FlingGestureHandler" : [ABI46_0_0RNFlingGestureHandler class],
                @"LongPressGestureHandler": [ABI46_0_0RNLongPressGestureHandler class],
                @"NativeViewGestureHandler": [ABI46_0_0RNNativeViewGestureHandler class],
                @"PinchGestureHandler": [ABI46_0_0RNPinchGestureHandler class],
                @"RotationGestureHandler": [ABI46_0_0RNRotationGestureHandler class],
                @"ForceTouchGestureHandler": [ABI46_0_0RNForceTouchHandler class],
                @"ManualGestureHandler": [ABI46_0_0RNManualGestureHandler class],
                };
    });
    
    Class nodeClass = map[handlerName];
    if (!nodeClass) {
        ABI46_0_0RCTLogError(@"Gesture handler type %@ is not supported", handlerName);
        return;
    }
    
    ABI46_0_0RNGestureHandler *gestureHandler = [[nodeClass alloc] initWithTag:handlerTag];
    [gestureHandler configure:config];
    [_registry registerGestureHandler:gestureHandler];
    
    __weak id<ABI46_0_0RNGestureHandlerEventEmitter> emitter = self;
    gestureHandler.emitter = emitter;
}


- (void)attachGestureHandler:(nonnull NSNumber *)handlerTag
               toViewWithTag:(nonnull NSNumber *)viewTag
              withActionType:(ABI46_0_0RNGestureHandlerActionType)actionType
{
    UIView *view = [_uiManager viewForABI46_0_0ReactTag:viewTag];
    
#ifdef ABI46_0_0RN_FABRIC_ENABLED
    if (view == nil) {
        // Happens when the view with given tag has been flattened.
        // We cannot attach gesture handler to a non-existent view.
        return;
    }
    
    // I think it should be moved to ABI46_0_0RNNativeViewHandler, but that would require
    // additional logic for setting contentView.ABI46_0_0ReactTag, this works for now
    if ([view isKindOfClass:[ABI46_0_0RCTViewComponentView class]]) {
        ABI46_0_0RCTViewComponentView *componentView = (ABI46_0_0RCTViewComponentView *)view;
        if (componentView.contentView != nil) {
            view = componentView.contentView;
        }
    }
    
    view.ABI46_0_0ReactTag = viewTag; // necessary for ABI46_0_0RNReanimated eventHash (e.g. "42onGestureHandlerEvent"), also will be returned as event.target  
#endif // ABI46_0_0RN_FABRIC_ENABLED

    [_registry attachHandlerWithTag:handlerTag toView:view withActionType:actionType];

    // register view if not already there
    [self registerViewWithGestureRecognizerAttachedIfNeeded:view];
}

- (void)updateGestureHandler:(NSNumber *)handlerTag config:(NSDictionary *)config
{
    ABI46_0_0RNGestureHandler *handler = [_registry handlerWithTag:handlerTag];
    [handler configure:config];
}

- (void)dropGestureHandler:(NSNumber *)handlerTag
{
    [_registry dropHandlerWithTag:handlerTag];
}

- (void)dropAllGestureHandlers
{
    [_registry dropAllHandlers];
}

- (void)handleSetJSResponder:(NSNumber *)viewTag blockNativeResponder:(NSNumber *)blockNativeResponder
{
    if ([blockNativeResponder boolValue]) {
        for (ABI46_0_0RNRootViewGestureRecognizer *recognizer in _rootViewGestureRecognizers) {
            [recognizer blockOtherRecognizers];
        }
    }
}

- (void)handleClearJSResponder
{
    // ignore...
}

- (id)handlerWithTag:(NSNumber *)handlerTag
{
  return [_registry handlerWithTag:handlerTag];
}


#pragma mark Root Views Management

- (void)registerViewWithGestureRecognizerAttachedIfNeeded:(UIView *)childView
{
    UIView *parent = childView;
    while (parent != nil && ![parent respondsToSelector:@selector(touchHandler)]) parent = parent.superview;

    // Many views can return the same touchHandler so we check if the one we want to register
    // is not already present in the set.
    UIView *touchHandlerView = [[parent performSelector:@selector(touchHandler)] view];
  
    if (touchHandlerView == nil) {
      return;
    }
  
    for (UIGestureRecognizer *recognizer in touchHandlerView.gestureRecognizers) {
      if ([recognizer isKindOfClass:[ABI46_0_0RNRootViewGestureRecognizer class]]) {
        return;
      }
    }
  
    ABI46_0_0RCTLifecycleLog(@"[GESTURE HANDLER] Initialize gesture handler for view %@", touchHandlerView);
    ABI46_0_0RNRootViewGestureRecognizer *recognizer = [ABI46_0_0RNRootViewGestureRecognizer new];
    recognizer.delegate = self;
    touchHandlerView.userInteractionEnabled = YES;
    [touchHandlerView addGestureRecognizer:recognizer];
    [_rootViewGestureRecognizers addObject:recognizer];
}

- (void)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    didActivateInViewWithTouchHandler:(UIView *)viewWithTouchHandler
{
    // Cancel touches in RN's root view in order to cancel all in-js recognizers

    // As scroll events are special-cased in RN responder implementation and sending them would
    // trigger JS responder change, we don't cancel touches if the handler that got activated is
    // a scroll recognizer. This way root view will keep sending touchMove and touchEnd events
    // and therefore allow JS responder to properly release the responder at the end of the touch
    // stream.
    // NOTE: this is not a proper fix and solving this problem requires upstream fixes to RN. In
    // particular if we have one PanHandler and ScrollView that can work simultaniously then when
    // the Pan handler activates it would still tigger cancel events.
    // Once the upstream fix lands the line below along with this comment can be removed
    if ([gestureRecognizer.view isKindOfClass:[UIScrollView class]]) return;

#ifdef ABI46_0_0RN_FABRIC_ENABLED
    ABI46_0_0RCTSurfaceTouchHandler *touchHandler = [viewWithTouchHandler performSelector:@selector(touchHandler)];
#else
    ABI46_0_0RCTTouchHandler *touchHandler = [viewWithTouchHandler performSelector:@selector(touchHandler)];
#endif
    [touchHandler setEnabled:NO];
    [touchHandler setEnabled:YES];

}

#pragma mark Events

- (void)sendEvent:(ABI46_0_0RNGestureHandlerStateChange *)event withActionType:(ABI46_0_0RNGestureHandlerActionType)actionType
{
    switch (actionType) {
        case ABI46_0_0RNGestureHandlerActionTypeReanimatedWorklet:
            [self sendEventForReanimated:event];
            break;
            
        case ABI46_0_0RNGestureHandlerActionTypeNativeAnimatedEvent:
            if ([event.eventName isEqualToString:@"onGestureHandlerEvent"]) {
                [self sendEventForNativeAnimatedEvent:event];
            } else {
                // Although onGestureEvent prop is an Animated.event with useNativeDriver: true,
                // onHandlerStateChange prop is still a regular JS function.
                // Also, Animated.event is only supported with old API.
                [self sendEventForJSFunctionOldAPI:event];
            }
            break;

        case ABI46_0_0RNGestureHandlerActionTypeJSFunctionOldAPI:
            [self sendEventForJSFunctionOldAPI:event];
            break;
            
        case ABI46_0_0RNGestureHandlerActionTypeJSFunctionNewAPI:
            [self sendEventForJSFunctionNewAPI:event];
            break;
    }
}

- (void)sendEventForReanimated:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to Reanimated.
#ifdef ABI46_0_0RN_FABRIC_ENABLED
    // Send event directly to Reanimated
    if (_reanimatedModule == nil) {
      _reanimatedModule = [_uiManager.bridge moduleForName:@"ReanimatedModule"];
    }
    
    [_reanimatedModule eventDispatcherWillDispatchEvent:event];
#else
    // In the old architecture, Reanimated overwrites ABI46_0_0RCTEventDispatcher
    // with ABI46_0_0REAEventDispatcher and intercepts all direct events.
    [self sendEventForDirectEvent:event];
#endif // ABI46_0_0RN_FABRIC_ENABLED
}

- (void)sendEventForNativeAnimatedEvent:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to NativeAnimatedModule.
    // Currently, NativeAnimated[Turbo]Module is ABI46_0_0RCTEventDispatcherObserver so we can
    // simply send a direct event which is handled by the observer but ignored on JS side.
    // TODO: send event directly to NativeAnimated[Turbo]Module
    [self sendEventForDirectEvent:event];
}

- (void)sendEventForJSFunctionOldAPI:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to JS (old ABI46_0_0RNGH API).
#ifdef ABI46_0_0RN_FABRIC_ENABLED
    [self sendEventForDeviceEvent:event];
#else
    [self sendEventForDirectEvent:event];
#endif // ABI46_0_0RN_FABRIC_ENABLED
}

- (void)sendEventForJSFunctionNewAPI:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to JS (new ABI46_0_0RNGH API).
    [self sendEventForDeviceEvent:event];
}

- (void)sendEventForDirectEvent:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to JS as a direct event.
    [_eventDispatcher sendEvent:event];
}

- (void)sendEventForDeviceEvent:(ABI46_0_0RNGestureHandlerStateChange *)event
{
    // Delivers the event to JS as a device event.
    NSMutableDictionary *body = [[event arguments] objectAtIndex:2];
    [_eventDispatcher sendDeviceEventWithName:@"onGestureHandlerStateChange" body:body];
}

@end
