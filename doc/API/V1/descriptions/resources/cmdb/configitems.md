#### Configuration Items

##### Special search behaviour

Since the properties of the version (i.e. the name) don't belong to the Config Item object itself, they must be referenced in the [```search```](#search_objects) definition using the prefix "```CurrentVersion.```", i.e. "```CurrentVersion.Name```". Attributes that are part of the sub-object "```Data```" of the "```CurrentVersion```" object have to be referenced with the prefix "```CurrentVersion.Data.```". Each structural level in the "```Data```" object has to be separated by "```.```", i.e. "```CurrentVersion.Data.SectionNetwork.FQDN```".

##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```CurrentVersion```|Adds the current version of the Config Item to the response. See sub-resource ["versions"](#cmdb_configitems__configitemid__versions_get).|