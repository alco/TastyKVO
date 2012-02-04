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

If you do not want to store the target, you can use an alternative API provided
by the library.

```objc
- (id)observeExternalNature:(id)nature
{
    [self observerChangesIn:nature
                  ofKeyPath:@"averageTemperature"
               withSelector:@selector(maybeBuyCoat)];
}

- (void)dealloc
{
    [self stopObserving];
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


## License & Feedback ##

The code is in the public domain. I encourage you to get it, try it, use it,
hack on it, and share your modifications with the world.

If you have found a defect, please file an issue on the project's [GitHub
page][1].

If you want your modifications to be merged with the main project fork, send me
a [pull request][2].

---

Originally written by Alexei Sholik <alcosholik@gmail.com> in February 2012.


  [1]: https://github.com/alco/TastyKVO
  [2]: https://github.com/alco/TastyKVO/pullrequests
