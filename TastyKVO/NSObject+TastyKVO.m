//
// TastyKVO adds two categories to the NSObject class that remove the hassle
// from and add convenience to dealing with the key-value observing mechanism.
//
// The code in this file is in the public domain.
//
// Originally written by Alexei Sholik <alcosholik@gmail.com> in February 2012.
// https://github.com/alco/TastyKVO
//
// Inspired by Andy Matuschak's NSObject+BlockObservation implementation
// https://gist.github.com/153676
//

#import "NSObject+TastyKVO.h"
#import <objc/runtime.h>


/**
 * Instances of this class are going to be the actual observers.
 */
@interface TastyObserverTrampoline: NSObject {
@private
    __weak id _observer;
    __weak id _target;
    NSString *_keyPath;
    TastyBlock _block;
    SEL _selector;
}

@property (nonatomic, copy) TastyBlock block;
@property (nonatomic, assign) SEL selector;

- (id)initWithObserver:(id)observer
                target:(id)target
               keyPath:(NSString *)keyPath;

- (void)stopObserving;

@end

static NSString *const kTastyObserverTrampolineContext =
                                            @"TastyObserverTrampolineContext";

@implementation TastyObserverTrampoline

@synthesize block = _block, selector = _selector;

- (id)initWithObserver:(id)observer
                target:(id)target
               keyPath:(NSString *)keyPath
{
    if ((self = [super init])) {
        _observer = observer;
        _target = target;
        _keyPath = [keyPath copy];
        [target addObserver:self
                 forKeyPath:keyPath
                    options:0
                    context:kTastyObserverTrampolineContext];
    }
    return self;
}

- (void)dealloc
{
    [self stopObserving];
    [_keyPath release];
    [_block release];
    [super dealloc];
}

- (void)stopObserving
{
    [_target removeObserver:self forKeyPath:_keyPath];
    _target = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSAssert(context == kTastyObserverTrampolineContext,
             @"%@ was registered as an observer with incorrect context."
              " This must be some tricky hack on part of the user", self);
    if (_block)
        _block(_observer, _target, change);
    else if (_selector)
        [_observer performSelector:_selector
                        withObject:_target
                        withObject:change];
    else
        NSAssert(0, @"No block nor selector provided for %@.", self);
}

@end

#pragma mark - Optional dealloc swizzling

#if defined(TASTYKVO_ENABLE_AUTOREMOVE) || defined(TASTYKVO_ENABLE_AUTOUNREGISTER)

static void _swizzle_dealloc(id obj, SEL new_dealloc_sel, IMP new_dealloc_imp)
{
    Class cls = [obj class];
    if ([cls instancesRespondToSelector:new_dealloc_sel])
        return;

    SEL dealloc_sel = @selector(dealloc);
    Method old_dealloc_method = class_getInstanceMethod(cls, dealloc_sel);
    const char *typeEncoding = method_getTypeEncoding(old_dealloc_method);
    class_replaceMethod(cls, new_dealloc_sel,
                        method_getImplementation(old_dealloc_method),
                        typeEncoding);
    class_replaceMethod(cls, dealloc_sel, new_dealloc_imp, typeEncoding);
}

#ifdef TASTYKVO_ENABLE_AUTOUNREGISTER
#ifndef TASTYKVO_HIDDEN_OBSERVER_DEALLOC_SELECTOR
#   define TASTYKVO_HIDDEN_OBSERVER_DEALLOC_SELECTOR @selector(_tastyKVO_hidden_observer_dealloc)
#endif
static void _extended_observer_dealloc(id self, SEL _cmd)
{
    [self stopObservingAllTargets];
    [self performSelector:TASTYKVO_HIDDEN_OBSERVER_DEALLOC_SELECTOR];
}
static void _swizzle_observer_dealloc(id observer)
{
    _swizzle_dealloc(observer, TASTYKVO_HIDDEN_OBSERVER_DEALLOC_SELECTOR, (IMP)_extended_observer_dealloc);
}
#endif

#ifdef TASTYKVO_ENABLE_AUTOREMOVE
#ifndef TASTYKVO_HIDDEN_TARGET_DEALLOC_SELECTOR
#   define TASTYKVO_HIDDEN_TARGET_DEALLOC_SELECTOR @selector(_tastyKVO_hidden_target_dealloc)
#endif
static void _extended_target_dealloc(id self, SEL _cmd)
{
    [self removeAllTastyObservers];
    [self performSelector:TASTYKVO_HIDDEN_TARGET_DEALLOC_SELECTOR];
}
static void _swizzle_target_dealloc(id target)
{
    _swizzle_dealloc(target, TASTYKVO_HIDDEN_TARGET_DEALLOC_SELECTOR, (IMP)_extended_target_dealloc);
}
#endif

#endif  // #if defined(TASTYKVO_ENABLE_AUTOREMOVE) || defined(TASTYKVO_ENABLE_AUTOUNREGISTER)

#pragma mark - Association of target with observer

static NSString *const kTastyKVOAssociatedTargetKey =
                                          @"org.tastykvo.associatedTargetKey";

static void _add_observation_target(id observer, id target)
{
#ifdef TASTYKVO_ENABLE_AUTOUNREGISTER
    _swizzle_observer_dealloc(observer);
#endif
    NSMutableSet *set =
             objc_getAssociatedObject(observer, kTastyKVOAssociatedTargetKey);
    if (set == nil) {
        set = [[NSMutableSet alloc] init];
        objc_setAssociatedObject(observer,
                                 kTastyKVOAssociatedTargetKey,
                                 set,
                                 OBJC_ASSOCIATION_RETAIN);
        [set release];
    }
    [set addObject:[NSValue valueWithNonretainedObject:target]];
}

static void _remove_observation_target(id observer, id target)
{
    NSMutableSet *set =
             objc_getAssociatedObject(observer, kTastyKVOAssociatedTargetKey);
    if (set) {
        [set removeObject:[NSValue valueWithNonretainedObject:target]];
        if ([set count] == 0)
            objc_setAssociatedObject(observer,
                                     kTastyKVOAssociatedTargetKey,
                                     nil,
                                     OBJC_ASSOCIATION_RETAIN);
    }
}

#pragma mark - The main API implementation

@implementation NSObject(TastyKVOExtension)

static NSString *const kTastyKVOAssociatedDictKey =
                                            @"org.tastykvo.associatedDictKey";

static dispatch_queue_t _lock_queue()
{
    static dispatch_queue_t lock_queue = NULL;
    static dispatch_once_t creation_predicate = 0;
    dispatch_once(&creation_predicate, ^{
        lock_queue = dispatch_queue_create(
            "org.tastykvo.lockQueue", 0);
    });
    return lock_queue;
}

/**
 * This function shall only be called inside dispatch_sync
 *
 * The 'self' argument represents the target to which 'observer' is being
 * added.
 */
static TastyObserverTrampoline *_new_trampoline(id self, id observer,
                                                NSString *keyPath)
{
    // Associate 'self' with the observer so that the user doesn't have to
    // store it herself
    _add_observation_target(observer, self);

    // This dictionary is used to store the 'paths' dictionary which, in turn,
    // stores the mapping from observer to its associated trampolines.
    NSMutableDictionary *dict =
                   objc_getAssociatedObject(self, kTastyKVOAssociatedDictKey);
    if (dict == nil) {
        dict = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(self,
                                 kTastyKVOAssociatedDictKey,
                                 dict,
                                 OBJC_ASSOCIATION_RETAIN);
        [dict release];
#ifdef TASTYKVO_ENABLE_AUTOREMOVE
        // Make the target remove all of its observers when it is deallocated.
        _swizzle_target_dealloc(self);
#endif
    }

    // For each key path the observer is registered for, there will be one
    // TastyObserverTrampoline instance in the 'paths' dict.
    NSValue *ptr = [NSValue valueWithPointer:observer];
    NSMutableDictionary *paths = [dict objectForKey:ptr];
    if (paths == nil) {
        paths = [[NSMutableDictionary alloc] init];
        [dict setObject:paths forKey:ptr];
        [paths release];
    }
    TastyObserverTrampoline *trampoline =
        [[TastyObserverTrampoline alloc]
            initWithObserver:observer target:self keyPath:keyPath];
    [paths setObject:trampoline forKey:keyPath];
    [trampoline release];

    return trampoline;
}

#pragma mark - Adding observers

- (void)addTastyObserver:(id)observer
              forKeyPath:(NSString *)multiKeyPath
            withSelector:(SEL)selector
{
    dispatch_sync(_lock_queue(), ^{
        NSArray *keys = [multiKeyPath componentsSeparatedByString:@"|"];
        for (NSString *key in keys) {
            TastyObserverTrampoline *trampoline =
                                         _new_trampoline(self, observer, key);
            trampoline.selector = selector;
        }
    });
}

- (void)addTastyObserver:(id)observer
              forKeyPath:(NSString *)multiKeyPath
               withBlock:(TastyBlock)block
{
    dispatch_sync(_lock_queue(), ^{
        NSArray *keys = [multiKeyPath componentsSeparatedByString:@"|"];
        for (NSString *key in keys) {
            TastyObserverTrampoline *trampoline =
                                         _new_trampoline(self, observer, key);
            trampoline.block = block;
        }
    });
}

static void _add_observer_vargs(id self, id observer, NSString *firstKey,
                                va_list args)
{
    NSString *multiKey = firstKey;
    while (multiKey) {
        unichar typeChar = [multiKey characterAtIndex:0];
        NSCAssert(typeChar == ':' || typeChar == '?',
                  @"Each multi-key must have a type encoding");

        NSArray *keys = [[multiKey substringFromIndex:1]
                                            componentsSeparatedByString:@"|"];
        BOOL isBlock = (typeChar == '?');
        if (isBlock) {
            TastyBlock block = va_arg(args, typeof(block));
            NSCAssert([block isKindOfClass:[NSObject class]],
                      @"This is not actually a block. Did you mean to use "
                       "'?' instead of ':'?");
            for (NSString *key in keys)
                [self addTastyObserver:observer
                            forKeyPath:key
                             withBlock:block];
        } else {
            SEL selector = va_arg(args, typeof(selector));
            NSCAssert(NSStringFromSelector(selector),
                      @"This is not actually a selector. Did you mean to use "
                       "':' instead of '?'?");
            for (NSString *key in keys)
                [self addTastyObserver:observer
                            forKeyPath:key
                          withSelector:selector];
        }
        multiKey = va_arg(args, typeof(multiKey));
    }
}

- (void)addTastyObserver:(id)observer
             forKeyPaths:(NSString *)firstKey, ...
{
    va_list args;
    va_start(args, firstKey);
    _add_observer_vargs(self, observer, firstKey, args);
    va_end(args);
}

#pragma mark - Removing observers

// This function is factored out so that it can be reused later
// in the TastyObserver implementation without dead-locking.
static void _remove_observer(id self, id observer)
{
    _remove_observation_target(observer, self);

    NSMutableDictionary *observerDict =
                   objc_getAssociatedObject(self, kTastyKVOAssociatedDictKey);
    NSValue *ptr = [NSValue valueWithPointer:observer];
    [observerDict removeObjectForKey:ptr];

    // Due to a bug in the obj-c runtime, this dictionary does not get
    // cleaned up on release when running without GC.
    if ([observerDict count] == 0)
        objc_setAssociatedObject(self,
                                 kTastyKVOAssociatedDictKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN);
}

#pragma mark

- (void)removeAllTastyObservers
{
    dispatch_sync(_lock_queue(), ^{
        NSMutableDictionary *observerDict =
                   objc_getAssociatedObject(self, kTastyKVOAssociatedDictKey);

        NSArray *pointers = [observerDict allKeys];
        for (NSValue *ptr in pointers)
            _remove_observer(self, [ptr pointerValue]);
    });
}

- (void)removeTastyObserver:(id)observer
{
    dispatch_sync(_lock_queue(), ^{
        _remove_observer(self, observer);
    });
}

- (void)removeTastyObserver:(id)observer forKeyPath:(NSString *)multiKeyPath
{
    if ([multiKeyPath isEqualToString:@"*"]) {
        [self removeTastyObserver:observer];
        return;
    }
    dispatch_sync(_lock_queue(), ^{
        NSMutableDictionary *observerDict =
                   objc_getAssociatedObject(self, kTastyKVOAssociatedDictKey);
        NSValue *ptr = [NSValue valueWithPointer:observer];
        NSMutableDictionary *dict = [observerDict objectForKey:ptr];
        if (dict == nil) {
            NSLog(@"%@: Ignoring attempt to remove non-existent observer %@"
                   " on %@ for multi-key path %@.",
                  NSStringFromSelector(_cmd), observer, self, multiKeyPath);
            return;
        }
        NSArray *keys = [multiKeyPath componentsSeparatedByString:@"|"];
        for (NSString *key in keys)
            [dict removeObjectForKey:key];
        if ([dict count] == 0)
            _remove_observer(self, observer);
    });
}

@end

#pragma mark - The alternative API implementation

@implementation NSObject(TastyObserver)

- (void)observeChangesIn:(id)target
               ofKeyPath:(NSString *)multiKeyPath
            withSelector:(SEL)selector
{
    [target addTastyObserver:self
                  forKeyPath:multiKeyPath
                withSelector:selector];
}

- (void)observeChangesIn:(id)target
               ofKeyPath:(NSString *)multiKeyPath
               withBlock:(TastyBlock)block
{
    [target addTastyObserver:self
                  forKeyPath:multiKeyPath
                   withBlock:block];
}

- (void)observeChangesIn:(id)target
              ofKeyPaths:(NSString *)firstKey, ...
{
    va_list args;
    va_start(args, firstKey);
    _add_observer_vargs(target, self, firstKey, args);
    va_end(args);
}

#pragma mark

- (void)stopObservingAllTargets
{
    dispatch_sync(_lock_queue(), ^{
        NSMutableSet *set =
                 objc_getAssociatedObject(self, kTastyKVOAssociatedTargetKey);
        if (set) {
            // Make a copy of all objects because the set will be modified
            // inside the loop.
            NSArray *targets = [set allObjects];
            for (NSValue *val in targets) {
                id target = [val nonretainedObjectValue];
                _remove_observer(target, self);
            }
            NSAssert(objc_getAssociatedObject(self, kTastyKVOAssociatedTargetKey) == nil,
                     @"Not all targets have been removed from observation");
        }
    });
}

- (void)stopObservingTarget:(id)target
{
    [target removeTastyObserver:self];
}

@end
