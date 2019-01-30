With the use of the optional query parameter ```fields``` it is possible to select which properties of an object should be included in the response. There are three ways to do this: a general style, a compact style and the use of pre-defined fieldsets.

** Usage in URL **

General:

``` bash
    .../<resource>?fields=<Object>.<Property>
```
Compact:

``` bash
    .../<resource>?fields=<Object>.[<Property>;<Property>;<Property>]
```
Please note that the "[]" characters do not declare optional content but define an actual array list in this case.

Fieldset:

``` bash
    .../<resource>?fields=:<Fieldset>
```

** Explanation **

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```|X|The object in the JSON response for which the properties should be selected.|
|```<Property>```|X|The name of the property that should be included in the response.|

When using the general style, multiple properties can be selected by multiplying the whole <Object>.<Property> part and separating it with comma. In the compact style the object has to be specified only once and the relevant properties are separated by semicolon in the array part.

A fieldset is a pre-defined property selection with a name. Please see the documentation of a specific resource whether fieldsets are available.


** Example **

Only select the attributes "UserLogin" and "UserID" from the users collection. In our example a fieldset named "Short" exists which selects those two properties.

General: 

``` bash
.../users?fields=User.UserLogin,User.UserID
```

Compact: 

``` bash
.../users?fields=User.[UserLogin;UserID]
```

Fieldset:

``` bash
.../users?fields=:Short
```
