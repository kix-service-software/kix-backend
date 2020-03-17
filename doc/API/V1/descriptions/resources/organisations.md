##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```TicketStats```|Adds some statistics to the response, about the tickets of this organisation. It will contain the number of tickets that are in a state of types "new" and "open", the number of pending tickets and the number of escalated tickets.|
|```AssignedConfigItems```|Adds assigend configitems (as IDs) to the response. It can be expanded to get the relevant configitems. The Assignment is configured in sysconfig option ```AssignedConfigItemsMapping```|
|```User```|If the corresponding contacts are included, this adds the corresponding users on their contacts. If the contacts are not included, this has no effect.|

