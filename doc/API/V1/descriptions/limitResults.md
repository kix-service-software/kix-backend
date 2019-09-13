There are two optional functions ```offset``` and ```limit``` to limit the number of items in a response of a collection resource. The combination of both functions is a powerful instrument to create paged responses.

### Using offsets

By using the optional query parameter ```offset``` a collection resource can be forced to return its response starting at a specific array index. This function will be executed before the [limit](#limit_results) function.

**Usage in URL**
``` bash
.../<resource>?offset=[<Object>:]<Offset>
```


**Explanation**

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```||The object in the JSON response to apply an offset to. If omitted the offset will be applied to all object lists in the response (if the response contains such).|
|```<Offset>```|yes|The numeric offset to apply.|

If a response contains different objects in different lists, separate offsets can be applied by separating them the with comma. 


**Example**

``` bash
.../users?offset=100,User:10
```


### Limit results

The optional query parameter ```limit``` allows to limit the number objects contained in the response of a collection.

**Usage in URL**
``` bash
.../<resource>?limit=[<Object>:]<Limit>
```


**Explanation**

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```||The object in the JSON response to apply a limit to. If omitted the limit will be applied to all object lists in the response (if the response contains such).|
|```<Limit>```|yes|The numeric limit to apply.|

If a response contains different objects in different lists, separate limits can be applied by separating them the with comma. 


**Example**

``` bash
.../users?limit=100,User:10
```