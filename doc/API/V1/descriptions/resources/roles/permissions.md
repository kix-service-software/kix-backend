For each existing role permissions can be created. A permission item has a ```TypeID``` which references a permission type defined in the resource [```/roles/permissiontypes```](#roles_permissiontypes_get). Additionally the target for the permission has to be defined. Each permission type has its own target schema. The following table lists the possible targets for each default permission type.

|ID|Permission Type|Permission Target|Example|
|-|-|-|-|
|1|Resource|collection resource URI|```/tickets```|
|2|Object|item resource URI|```/tickets/123```|
|3|PropertyValue|&lt;ObjectType&gt;.&lt;Property&gt; EQ &lt;Value&gt;|```Ticket.QueueID EQ 123```|

The permission value itself is a bitmask with the following values:

|Value|Permission|
|-|-|
|```0x0000```|NONE|
|```0x0001```|CREATE|
|```0x0002```|READ|
|```0x0004```|UPDATE|
|```0x0008```|DELETE|
|```0xf000```|DENY|