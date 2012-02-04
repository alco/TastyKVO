#import <SenTestingKit/SenTestingKit.h>


@class TargetObject;
@class ObserverObject;

@interface TastyKVOExtensionTests: SenTestCase {
@private
    TargetObject *_target;
    ObserverObject *_observer;
}
@end
