##### Supported Includes

In addition to its sub-resources this resource supports the following includes.

|Include|Description|
|-|-|
|```TicketStats```|Adds some statistics to the response, about the tickets of this contact. It will contain the number of tickets that are in a state of types "new" and "open", the number of pending tickets and the number of escalated tickets.|

This resource supports a special ```search``` property

|Search|Description|
|-|-|
|```Fulltext```| Searches with the given value in the following contact attributes: login, firstname, lastname, email, title, phone, fax, mobile, street, zip, city, country. Some logical operators are possible: "+" or "&" as AND, "\|" as OR and "\*" as any string, e.g. "john&doe" or "j\*+doe\|james"|
