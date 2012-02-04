#import <SenTestingKit/SenTestingKit.h>
#import "Helpers.h"


@interface TastyKVODeallocationTests: SenTestCase {
@private
    TargetObject *_target;
    ObserverObject *_observer;
}
@end
