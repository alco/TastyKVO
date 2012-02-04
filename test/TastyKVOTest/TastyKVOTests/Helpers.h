#import <Foundation/Foundation.h>


@interface TargetObject: NSObject {
@private
    BOOL _boolVar;
    int _intVar;
    float _floatVar;
    NSString *_message;
}
@property (nonatomic) BOOL boolVar;
@property (nonatomic) int intVar;
@property (nonatomic) float floatVar;
@property (nonatomic, copy) NSString *message;
@end

#pragma mark -

@interface ObserverObject: NSObject {
@private
    BOOL _flag;
    int _counter;
}
@property (nonatomic) BOOL flag;
@property (nonatomic) int counter;

- (void)flipFlag;
- (void)increment;
@end
