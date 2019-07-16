##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```SubQueues```|Adds the die tree of sub-queues to the response.|
|```TicketStats```|Adds some statistics to the response, about the tickets in this queue. It will contain the total number of tickets, the number of locked tickets and the number of escalated tickets, based on the given URL parameter ```TicketStats.StateType``` or ```TicketStats.StateID```. Both can contain multiple values separated by a comma.|
|```Tickets```|Adds the list of tickets to the response.|
