##### Special search behaviour

Since the preferences of the user don't belong to the Config Item object itself, they must be referenced in the [```search```](#search_objects) definition using the prefix "```Preferences.```", i.e. "```Preferences.MyQueues```".

##### Supported Includes

In addition to its sub-resources this resource supports the following includes.

|Include|Description|
|-|-|
|```Contact```|Adds the corresponding contact to this user. Returns empty if no contact exists. The contact contains the personal data for this user (names, address, ...). The relevant "link" attribute is "AssignedUserID" in the contact object.|
