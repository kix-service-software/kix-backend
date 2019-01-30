Every collection resource supports the sorting of items in the response. This can be done with the optional query parameter ```sort```.

** Usage in URL **
``` bash
    .../<resource>?sort=<Object>.[-]<Fieldname>[:<Type>]
```


** Explanation **

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```|yes|The object in the JSON response to be sorted.|
|```<Fieldname>```|yes|The attribute in each item of the response to be sorted by. If the fieldname starts with ```-``` the attribute will be sorted in descending order.|
|```<Type>```||The type of data that should be used to compare the value. If not given, the the value will be sorted as ASCII text and case-insensitive.|


** Supported types **

|Type|Description|
|-|-|
|```numeric```|The attribute value will be sorted as a number (integer or float).|
|```textual```|The attribute value will be sorted as ASCII text. Case and spaces will be ignored.|
|```natural```|Multi-type-sort. Sorting of different parts of value, starting with spaces, followed by numbers, non-text characters and text characters. Additionally subsidiary words will be moved to the end of the value. Example: "The Book of Verse" will be sorted as "Book of Verse, The"|
|```date```|The attribute value will be sorted as a date in the form ```YYYY-MM-DD```|
|```datetime```|The attribute value will be sorted as a date in the form ```YYYY-MM-DD HH24:MI:SS```|

Multiple attributes can be sorted by separating the sort definition with comma. 


** Example **

Query all users and sort the result for the creation time ascending + UserID descending + first name ascending.

``` bash
.../users?sort=User.CreateTime:date,User.-UserID:numeric,User.UserFirstname
```
