When requesting items and using the optional function [```include```](#include_more_information) to include another depending resource, a list of IDs will be the result. This can be used to count the relevant objects without the need to include unnecessary and huge additional data. To replace this list of IDs with the actual objects you can use the optional query parameter ```expand```. Whether a resource supports expanding of includes and which includes can be expanded can be found in the documentation of the specific resource.

** Usage in URL **
``` bash
    .../<resource>?expand=<What>
```


** Explanation **

|Parameter|Required?|Description|
|-|:-:|-|
|```<What>```|yes|The includes in the response that should be expanded. You can specify multiple ones by separating them with comma.|


** Example **

Query all customers and include a list of tickets and contacts of each customer. Expand the list of tickets with the actual ticket objects.

``` bash
.../customers?include=Tickets,Contacts&expand=Tickets
```