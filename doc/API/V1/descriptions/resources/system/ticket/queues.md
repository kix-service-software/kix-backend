##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```SubQueues```|Adds the die tree of sub-queues to the response.|
|```TicketStats```|Adds some statistics to the response, about the tickets in this queue. It will contain the total number of tickets and the number of locked tickets, based on the given URL parameter ```TicketStats.StateType``` or ```TicketStats.StateID```. Both can contain multiple values separated by a comma. The two virtual StateTypes ```Open``` and ```Viewable``` represent only the viewable state types (see SysConfig option ```Ticket::ViewableStateType```).|
|```Tickets```|Adds the list of tickets to the response.|

##### Supported Generic Properties
The queues resource supports the generic property ```Permissions``` in POST and PATCH requests. This property is an array of base permission objects. 

**Base Permission Object (Example) **
``` bash
    {
        
        "Type":       "Base",
        "RoleID":     123,
        "Permission": "READ+WRITE"
    }
```
