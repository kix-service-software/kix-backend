#### Dynamic Fields

Allows to create, get, update and delete dynamic fields.
On Update the full config has to be given if changed, else the missing attributes are lost and only not internal fields are updatable.

##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```Config```|Adds the config of the dynamic field depending on its field type.|