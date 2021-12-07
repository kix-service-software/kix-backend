This resource allows readable access to the logs files in the KIX backend log directory.

##### Tailing and Filtering

With ```Tail``` you can specify the number of lines you want to fetch from the end of the file. Additionally you can filter for log categories by giving a comma separated list as ```Categories```. Combining both options, you can do something like "give me the last 10 errors or debug messages". The tailed and/or filtered content will only be returned, if you include ```Content```.

##### Supported Includes

|Include|Description|
|-|-|
|```Content```|Adds the content of the log file (base64 encoded).|
