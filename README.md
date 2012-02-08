TastyKVO
========

Simplified key-value observing for the masses. This is a
single-header-single-implementation-file library. Supports iOS 4.0 and Mac OS X
10.6 and above.


## Setup ##

Add the _TastyKVO_ subdirectory as a group to your project, `#import
"NSObject+TastyKVO.h"` and start using the tasty API.


## Examples ##

The methods provided by **TastyKVO** are documented in the
_NSObject+TastyKVO.h_ file. The following examples demonstrate some common use
cases.

### Using blocks ###

```objc
// MyObject.m

- (void)observeNature
{
    [_nature addTastyObserver:self
                      keyPath:@"windSpeed"
                    withBlock:^(MyObject *self, id target, NSDictionary *change) {
                                  // take measures
                              }];
}

- (void)dealloc
{
    [_nature removeTastyObserver:self];
    [super dealloc];
}
```

### Using custom selector ###

```objc
// MyObject.m

@implementation MyObject

- (void)aMethod
{
    NSLog(@"Hooray!");
}

- (id)initWithTarget:(id)target
{
    if ((self = [super init])) {
        _target = target;
        [_target addTastyObserver:self
                          keyPath:@"someProperty"
                     withSelector:@selector(aMethod)];
    }
    return self;
}

- (void)dealloc
{
   [_target removeTastyObserver:self];
   [super dealloc];
}
```

### Implicitly storing the target ###

You are not obliged to store the target, the library is already doing it for
you. Simply use the `stopObservingAllTargets` method to unregister from KVO
notifications.

```objc
- (id)observeExternalNature:(id)nature
{
    [self observeChangesIn:nature
                 ofKeyPath:@"averageTemperature"
              withSelector:@selector(buyCoatOrShorts)];
}

- (void)dealloc
{
    [self stopObservingAllTargets];
    [super dealloc];
}
```

### Observing multiple properties ###

The code below

```objc
TastyBlock block = ...;
[target addTastyObserver:self forKeyPath:@"property|anotherProperty" withBlock:block];
```

is equivalent to the following code

```objc
TastyBlock block = ...;
[target addTastyObserver:self forKeyPath:@"property" withBlock:block];
[target addTastyObserver:self forKeyPath:@"anotherProperty" withBlock:block];
```


## Memory Management ##

_The library has not been tested with GC_.

_The library has not been tested with ARC_.

It is ***important*** that you unregister an object from KVO notifications
before it is deallocated. Failing to do so may cause unpredictable consequences
which can't even be tested reliably. Luckily, **TastyKVO** provides a way to
enforce this policy automatically.

There are two macros that you can define in order to enable automatic observer
removal.

1. `TASTYKVO_ENABLE_AUTOREMOVE`. When defined, each target (the object which
   has at least one observer) will remove all of its observers prior to
   deallocation.

2. `TASTYKVO_ENABLE_AUTOUNREGISTER`. When defined, each observer will stop
   observing all of its targets prior to deallocation.

When you define both macros, either at the top level in your project's build
settings or for the single file `NSObject+TastyKVO.m`, you no longer need to
call any of the `stopObserving...` or `removeTastyObserver...` methods.

### Implementation details ###

Under the hood, the automatic removal and unregistration are implemented by
means of swizzling the `dealloc` method. That is, when you register an observer
via one of the `addTastyObserver...` or `observeChangesIn...` methods, the
object's own implementation of dealloc is replaced with a custom one (the
object being the target, the observer, or both, depending on the macros
defined). This new implementation calls `removeAllTastyObservers` or
`stopObservingAllTargets` first and then invokes the original dealloc method of
the object.


## License & Feedback ##

The code is in the public domain. I encourage you to get it, try it, use it,
hack on it, and share your modifications with the world.

If you have found a defect, please file an issue on the project's [GitHub
page][1].

If you want your modifications to be merged with the main project fork, send me
a [pull request][2].

If you have suggestions, comments or other kinds of feedback, don't hesitate to
contact me directly. My name is Alex.

---

Originally written by Alexei Sholik <alcosholik@gmail.com> in February 2012.


  [1]: https://github.com/alco/TastyKVO
  [2]: https://github.com/alco/TastyKVO/pulls
