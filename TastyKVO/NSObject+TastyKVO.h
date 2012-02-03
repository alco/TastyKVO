//
// TastyKVO adds two categories to the NSObject class that remove the hassle
// from and add convenience to dealing with the key-value observing mechanism.
//
// The code in this file is in the public domain.
//
// Originally created by Alexei Sholik in February 2012.
// https://github.com/alco/TastyKVO
//
// Inspired by Andy Matuschak's NSObject+BlockObservation implementation
// https://gist.github.com/153676
//

/**
 * The block type used for blocks invoked when an observed change occurs.
 *
 * The first argument is a reference to the observer. It is named 'self'
 * intentionally and it is a good idea to follow this convention when writing
 * blocks for use with TastyKVO.
 *
 * In the conventional KVO API it is common to register 'self' as an observer
 * and unregister in its 'dealloc' method.  When we start using blocks with
 * KVO, the 'dealloc' method might not get called at all due to a retain-cycle
 * introduced inadvertently by referencing an ivar inside a block.
 *
 * By naming the first argument 'self', we shadow the previous reference to
 * self and avoid it being retained (blocks do not retain their arguments).
 * Having this new 'self' in place, you can freely reference ivars inside a
 * block and not be afraid of introducing a retain-cycle.
 *
 * This whole idea is borrowed from Jonathan Wight's own implementation of the
 * "KVO + blocks = love" thing --> http://toxicsoftware.com/kvoblocks/
 */
typedef void (^TastyBlock)(id self, id target, NSDictionary *change);


#pragma mark - General considerations

/**
 * The 'multiKeyPath' argument in all of the methods defined in this file is an
 * extensions of the key path defined by KVO. It may contain more than one key
 * path with individual keys separated by a bar (|).
 *
 * For instance, the code
 *
 *   [target addObserver:self
 *            forKeyPath:@"someProperty|anotherProperty"
 *          withSelector:@selector(triggerChange)];
 *
 * is equivalent to the following sequential invocations
 *
 *   [target addObserver:self
 *            forKeyPath:@"someProperty"
 *          withSelector:@selector(triggerChange)];
 *   [target addObserver:self
 *            forKeyPath:@"anotherProperty"
 *          withSelector:@selector(triggerChange)];
 *
 * ---
 *
 * The 'change' dictionary passed to the selector or the block contains the
 * change of the property that actually triggered the KVO notification.
 *
 * ---
 *
 * The 'observer' is not retained in any of the methods.
 */


@interface NSObject(TastyKVOExtension)

#pragma mark - Adding observer

/**
 * The 'selector' in its full form has the following signature
 *
 *   - (void)observeTarget:(id)target change:(NSDictionary *)change
 *
 * where 'target' and 'change' are equal to the TastyBlock's arguments with the
 * same names. However, you may safely omit the last one or both arguments.
 * Thus, you could pass a selector with the signature
 *
 *   - (void)observeTarget:(id)target
 *
 * or even
 *
 *   - (void)selector
 */
- (void)addTastyObserver:(id)observer
              forKeyPath:(NSString *)multiKeyPath
            withSelector:(SEL)selector;

/**
 * This method is equivalent to the previous one except instead of selector it
 * accepts a block.
 */
- (void)addTastyObserver:(id)observer
              forKeyPath:(NSString *)multiKeyPath
               withBlock:(TastyBlock)block;

/**
 * This is a convenience method that accepts multi-key paths, each followed by
 * either a selector or a block. You must explicitly state the type of the
 * argument following a multi-key path by using a colon (:) for selectors and a
 * question mark (?) for blocks.
 *
 * Example:
 *
 *   [target
 *     addTastyObserver:self
 *          forKeyPaths:
 *            @":some_property",
 *                @selector(triggerChange),
 *            @"?another_property|yet_another_one",
 *                ^(id self, id target, NSDictionary *change) {
 *                    NSLog(@"Either 'another_property' or 'yet_another_one' changed");
 *                },
 *            nil];
 */
- (void)addTastyObserver:(id)observer
             forKeyPaths:(NSString *)firstKey, ... NS_REQUIRES_NIL_TERMINATION;

#pragma mark - Removing observer

/**
 * Remove the observer for each key path it is subscribed to.
 */
- (void)removeTastyObserver:(id)observer;

/**
 * Remove the observer for the specified multi-key path.
 *
 * 'multiKeyPath' may also have the special value of @"*", in which case the
 * observer is removed for each key path it is subscribed to, similar to the
 * previous method.
 */
- (void)removeTastyObserver:(id)observer
                 forKeyPath:(NSString *)key;
@end


#pragma mark - An alternative way to do the same thing

/**
 * The TastyObserver category is simply a wrapper over the methods defined in
 * TastyKVOExtension which restates the functionality of those methods from the
 * observer's point of view. That is to say, the methods defined below allow
 * you to subscribe to KVO notifications from the first person.
 *
 * An important thing to remember is that the methods defined in one or the
 * other category are not interchangeable. That is, you cannot register for KVO
 * notifications using one of the 'addTastyObserver:...' methods and unregister
 * using the 'stopObserving...' methods.
 */
@interface NSObject(TastyObserver)

/**
 * Each of the following 'observeChangesIn...' methods registers 'self' as an
 * observer with the 'target'.
 */
- (void)observeChangesIn:(id)target
               ofKeyPath:(NSString *)multiKeyPath
            withSelector:(SEL)selector;

- (void)observeChangesIn:(id)target
               ofKeyPath:(NSString *)multiKeyPath
               withBlock:(TastyBlock)block;

- (void)observeChangesIn:(id)target
              ofKeyPaths:(NSString *)firstKey, ... NS_REQUIRES_NIL_TERMINATION;

/**
 * This method causes the receiver to unsubscribe from ALL objects that it has
 * previously registered itself as an observer with. A perfect candidate for
 * the dealloc method. Although it is possible to invoke this method
 * automatically (see below).
 */
- (void)stopObserving;

/**
 * Unsubscribe from KVO notifications emitted by 'target'.
 */
- (void)stopObservingTarget:(id)target;

@end
