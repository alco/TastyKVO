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
            counter = _counter;

- (void)flipFlag
{
    _flag = !_flag;
}

- (void)increment
{
    ++_counter;
}

@end
