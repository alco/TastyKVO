#import "Helpers.h"


@implementation TargetObject

@synthesize boolVar = _boolVar,
            intVar = _intVar,
            floatVar = _floatVar,
            message = _message;

- (void)dealloc
{
    [_message release];
    [super dealloc];
}

@end

#pragma mark -

@implementation ObserverObject

@synthesize flag = _flag,
            counter = _counter,
            target = _target,
            changeDict = _changeDict;

- (void)flipFlag
{
    _flag = !_flag;
}

- (void)increment
{
    ++_counter;
}

- (void)onearg:(id)target
{
    _target = target;
}

- (void)first:(id)target second:(NSDictionary *)change
{
    _target = target;
    if (_changeDict != change) {
        [_changeDict release];
        _changeDict = [change retain];
    }
}

@end
