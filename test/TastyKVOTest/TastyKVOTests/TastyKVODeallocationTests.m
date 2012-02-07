#import "TastyKVODeallocationTests.h"

#import "NSObject+TastyKVO.h"
#import <objc/runtime.h>


static int observerDeallocFlag;

@interface ObserverObject(AugmentedDealloc)
- (void)dealloc;
@end

@implementation ObserverObject(AugmentedDealloc)
- (void)dealloc
{
    observerDeallocFlag = 1;
    [super dealloc];
}
@end

#pragma mark -

static int targetDeallocFlag;

@interface TargetObject(AugmentedDealloc)
- (void)dealloc;
@end

@implementation TargetObject(AugmentedDealloc)
- (void)dealloc
{
    targetDeallocFlag = 1;
    [_message release];
    [super dealloc];
}
@end

#pragma mark -

@interface RetainCycleObject: NSObject {
@private
    int _ivar;
}
@property (nonatomic) int ivar;
- (id)initWithTarget:(id)target;
@end

@implementation RetainCycleObject

@synthesize ivar = _ivar;

- (void)increment
{
    ++_ivar;
}

- (id)initWithTarget:(id)target
{
    if ((self = [super init])) {
        [self observeChangesIn:target
                     ofKeyPath:@"intVar|boolVar|floatVar|message"
                     withBlock:^(RetainCycleObject *self, id target, NSDictionary *change) {
                         [self increment];
                         _ivar += 2;
                         self.ivar += 3;
                     }];
    }
    return self;
}

- (void)dealloc
{
    [self stopObservingAllTargets];
    observerDeallocFlag += 100;
    [super dealloc];
}

@end

#pragma mark -


static NSString *const kAssociatedKey = @"org.tastykvo.associatedDictKey";
static NSString *const kAssociatedTargetKey = @"org.tastykvo.associatedTargetKey";

@implementation TastyKVODeallocationTests

- (void)setUp
{
    [super setUp];

    _target = [[TargetObject alloc] init];
    _observer = [[ObserverObject alloc] init];
    observerDeallocFlag = 0;
    targetDeallocFlag = 0;
}

- (void)tearDown
{
    [_observer release];
    [_target release];

    [super tearDown];
}

#pragma mark -

- (void)testTargetDealloc_1
{
    STAssertEquals(targetDeallocFlag, 0, @"");
    TargetObject *target = [[TargetObject alloc] init];
    [target addTastyObserver:self forKeyPath:@"message" withSelector:@selector(whatever)];
    [target release];
    STAssertEquals(targetDeallocFlag, 1, @"Target's dealloc was not called");
}

- (void)testTargetDealloc_2
{
    STAssertEquals(targetDeallocFlag, 0, @"");
    TargetObject *target = [[TargetObject alloc] init];
    [target addTastyObserver:self forKeyPath:@"message" withSelector:@selector(whatever)];
    [target removeTastyObserver:self];
    [target release];
    STAssertEquals(targetDeallocFlag, 1, @"Target's dealloc was not called");
}

- (void)testObserverDealloc_1
{
    STAssertEquals(observerDeallocFlag, 0, @"");
    ObserverObject *observer = [[ObserverObject alloc] init];
    [_target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    [observer release];
    STAssertEquals(observerDeallocFlag, 1, @"Observer's dealloc was not called");
}

- (void)testObserverDealloc_2
{
    STAssertEquals(observerDeallocFlag, 0, @"");
    ObserverObject *observer = [[ObserverObject alloc] init];
    [_target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    [_target removeTastyObserver:observer];
    [observer release];
    STAssertEquals(observerDeallocFlag, 1, @"Observer's dealloc was not called");
}

- (void)testBothDeallocs_1
{
    STAssertEquals(targetDeallocFlag, 0, @"");
    STAssertEquals(observerDeallocFlag, 0, @"");
    TargetObject *target = [[TargetObject alloc] init];
    ObserverObject *observer = [[ObserverObject alloc] init];
    [target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    [target release];
    STAssertEquals(targetDeallocFlag, 1, @"Target's dealloc was not called");
    [observer release];
    STAssertEquals(observerDeallocFlag, 1, @"Observer's dealloc was not called");
}

- (void)testBothDeallocs_2
{
    STAssertEquals(targetDeallocFlag, 0, @"");
    STAssertEquals(observerDeallocFlag, 0, @"");
    TargetObject *target = [[TargetObject alloc] init];
    ObserverObject *observer = [[ObserverObject alloc] init];
    [target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];

    // A different release order this time
    [observer release];
    STAssertEquals(observerDeallocFlag, 1, @"Observer's dealloc was not called");
    [target release];
    STAssertEquals(targetDeallocFlag, 1, @"Target's dealloc was not called");
}

- (void)testBlockDealloc
{
    RetainCycleObject *obj = [[RetainCycleObject alloc] initWithTarget:_target];
    STAssertEquals([obj ivar], 0, @"Unexplained change when registering an observer");
    STAssertNotNil(objc_getAssociatedObject(_target, kAssociatedKey), @"Wrong associated key?");

    _target.intVar = 1;
    STAssertEquals([obj ivar], 6, @"intVar's change was not caught");
    _target.boolVar = YES;
    STAssertEquals([obj ivar], 12, @"boolVar's change was not caught");
    _target.floatVar = 1.f;
    STAssertEquals([obj ivar], 18, @"floatVar's change was not caught");
    _target.message = @"bye";
    STAssertEquals([obj ivar], 24, @"message's change was not caught");

    [obj release];
    STAssertNil(objc_getAssociatedObject(_target, kAssociatedKey), @"Observer was not actually removed");
    STAssertEquals(observerDeallocFlag, 100, @"obj's dealloc was not called?");
    _target.intVar = 2;
    _target.boolVar = NO;
    _target.floatVar = 0.f;
    _target.message = @"";
    STAssertEquals(observerDeallocFlag, 100, @"obj's dealloc called multiple times?");
}

- (void)testAssociation
{
    ObserverObject *observer = [[ObserverObject alloc] init];
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"Wrong associated target key?");
    STAssertNil(objc_getAssociatedObject(_target, kAssociatedKey), @"Wrong associated key?");

    [observer observeChangesIn:_target ofKeyPath:@"message" withSelector:@selector(whatever)];
    STAssertNotNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"Failed to associate target with observer");
    STAssertNotNil(objc_getAssociatedObject(_target, kAssociatedKey), @"Failed to associate trampoline with target");

    [observer stopObservingAllTargets];
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"Did not stop observing properly");
    STAssertNil(objc_getAssociatedObject(_target, kAssociatedKey), @"Did not remove the observer properly");

    [observer release];
}

@end
