##### Supported Includes

In addition to its sub-resources this resource supports the following includes.

|Include|Description|
|-|-|
|```TicketStats```|Adds some statistics to the response, about the tickets of this contact. It will contain the number of tickets that are in a state of types "new" and "open", the number of pending tickets and the number of escalated tickets.|
|```AssignedConfigItems```|Adds assigend configitems (as IDs) to the response. It can be expanded to get the relevant configitems. The Assignment is configured in sysconfig option ```AssignedConfigItemsMapping```|
|```User```|Adds the corresponding user to the response. If no user is assigned to this contact, the attribute is empty (the relevant "link" attribute is "AssignedUserID"). A User is necessary to allow access to the system for the contact (the contact itself contains only the personal data).|
|```DynamicFields```|Includes the assigned Dynamic Fields and their prepared values. You can disable the preparation of specific DF types with the URI parameter ```NoDynamicFieldDisplayValues```, which is a comma separated list of DF types.|

This resource supports a special ```search``` property

|Search|Description|
|-|-|
|```Fulltext```| Searches with the given value in the following contact attributes: login, firstname, lastname, email, title, phone, fax, mobile, street, zip, city, country. Some logical operators are possible: "+" or "&" as AND, "\|" as OR and "\*" as any string, e.g. "john&doe" or "j\*+doe\|james"|
