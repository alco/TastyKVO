#import "TastyKVOAutoRemovalTests.h"
#import "Helpers.h"
#import "NSObject+TastyKVO.h"
#import <objc/runtime.h>


static NSString *const kAssociatedKey = @"org.tastykvo.associatedDictKey";
static NSString *const kAssociatedTargetKey = @"org.tastykvo.associatedTargetKey";


static int targetDeallocFlag;
static int observerDeallocFlag;

@implementation TargetObject(AugmentedDealloc)
- (void)dealloc
{
    ++targetDeallocFlag;
    [_message release];
    [super dealloc];
}
@end

@implementation ObserverObject(AugmentedDealloc)
- (void)dealloc
{
    ++observerDeallocFlag;
    [super dealloc];
}
@end

#pragma mark -

@implementation TastyKVOAutoRemovalTests

- (void)setUp
{
    [super setUp];
    
    targetDeallocFlag = 0;
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testOneTarget
{
    TargetObject *target = [[TargetObject alloc] init];
    ObserverObject *observer = [[ObserverObject alloc] init];
    
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"Wrong associated target key?");
    STAssertNil(objc_getAssociatedObject(target, kAssociatedKey), @"Wrong associated key?");
    
    [target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    target.intVar = 10;
    STAssertEquals([observer counter], 1, @"KVO notification was not triggered");
    
    ObserverObject *secondObserver = [[ObserverObject alloc] init];
    
    [target addTastyObserver:secondObserver forKeyPath:@"intVar" withSelector:@selector(increment)];
    target.intVar = 1;
    STAssertEquals([observer counter], 2, @"First observer got blocked by the second one?");
    STAssertEquals([secondObserver counter], 1, @"Second observer did not observe the intVar notification");
    
    [target release];
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"The observer was not automatically removed");
    STAssertNil(objc_getAssociatedObject(secondObserver, kAssociatedTargetKey), @"The secondObserver was not automatically removed");
    
    [observer release];
    [secondObserver release];
}

- (void)testOneObserver
{
    ObserverObject *observer = [[ObserverObject alloc] init];
    
    TargetObject *target1 = [[TargetObject alloc] init];
    TargetObject *target2 = [[TargetObject alloc] init];
    
    [observer observeChangesIn:target1 ofKeyPath:@"intVar" withSelector:@selector(increment)];
    [observer observeChangesIn:target2 ofKeyPath:@"intVar" withSelector:@selector(increment)];
    
    target1.intVar = 10;
    STAssertEquals([observer counter], 1, @"KVO notification was not triggered for target1");
    
    target2.intVar = 1;
    STAssertEquals([observer counter], 2, @"KVO notification was not triggered for target2");
    
    [target1 release];
    [target2 release];
    
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"The observer was not automatically removed");    
    [observer release];
}

- (void)testOwnDealloc
{
    ObserverObject *observer = [[ObserverObject alloc] init];
    TargetObject *target = [[TargetObject alloc] init];
    [target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    [target release];
    STAssertEquals(targetDeallocFlag, 1, @"Target's own dealloc was not called");
    STAssertNil(objc_getAssociatedObject(observer, kAssociatedTargetKey), @"The observer was not automatically removed");
    [observer release];
}

- (void)testObserverEarlyRelease
{
    ObserverObject *observer = [[ObserverObject alloc] init];
    TargetObject *target = [[TargetObject alloc] init];
    [target addTastyObserver:observer forKeyPath:@"intVar" withSelector:@selector(increment)];
    [observer release];
    [target release];
}

- (void)testObserverAndTargetInOneObject
{
    ObserverObject *obj = [[ObserverObject alloc] init];
    ObserverObject *observer = [[ObserverObject alloc] init];
    TargetObject *target = [[TargetObject alloc] init];
    
    [obj addTastyObserver:observer forKeyPath:@"flag" withSelector:@selector(increment)];
    [obj observeChangesIn:target ofKeyPath:@"boolVar" withSelector:@selector(increment)];
    
    obj.flag = YES;
    STAssertEquals([observer counter], 1, @"Observer was not triggered for keypath 'flag'");

    target.boolVar = YES;
    STAssertEquals([obj counter], 1, @"Obj was not triggered for keypath 'boolVar'");
    
    observerDeallocFlag = 0;
    [obj release];
    STAssertEquals(observerDeallocFlag, 1, @"Obj's own dealloc was not invoked");

    [target release];
    [observer release];
}

@end
