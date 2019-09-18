#### Versions of a Config Item

##### Supported Includes

In addition to its sub-resources (as far as they exist), this resource supports the following includes.

|Include|Description|
|-|-|
|```Definition```|Adds the corresponding definition of the Config Item class to the response. See sub-resource ["definitions"](#cmdb_classes__classid__classes_get).|
|```Data```|Adds the version data to the response.|
|```PreparedData```|Adds the prepared data to the response. The structure of this object is based on the structure of the definition. For every value in the ```Data``` object an array item will be created. Please see the description below.|

**Structure of the Data attribute**

The structure of the ```Data``` attribute is based on the structure and configuration of the corresponding Config Item class definition. The following rules apply:

1\. The ```Key```in the attribute definition is the attribute name

    ``` bash
    {
        "AttributeKey": ...
    }
    ```

2\. If CountMax in the attribute definition is 1 (or omitted) the value is assigned directly

    ``` bash
    {
        "AttributeKey": "Value"
    }
    ```

3\. If CountMax in the attribute definition is > 1 the value is assigned as an array

    ``` bash
    {
        "AttributeKey": [
            "Value1",
            "Value2",
            "Value3"
        ]
    }
    ```

4\. If the attribute has a value AND also contains values in a sub-structure, the attribute is an object and its value will be assigned to an attribute with the same name with this object

    ``` bash
    {
        "AttributeKey": {
            "AttributeKey": "Value",
            "SubAttributKey1": "...",
            "SubAttributKey2": {
                "SubSubAttributKey1": "..."
            }
        }
    }
    ```


**Format of the PreparedData array items**

``` bash
{ 
     "Key": "<the key from the attribute definition>",
     "Label": "<the name from the attribute definition>",
     "Type": "<the type from the attribute definition>",
     "Value": "<the internal value of the attribute>",
     "DisplayValue": "<the display value of the attribute>",
     "Sub": [...]
}
``` 

The ```Sub``` attribute only exists if the attribute definition contains a sub-structure and ony if the sub-structure contains data.

The ```DisplayValue``` attribute is not available for attribute of the type ```Attachment```

##### Supported attribute types 

When creating a version of a Config Item only the following attribute types are supported:

|Attribute type|Description|Value in request|Example in POST|
|-|-|-|-|
|```Attachment```|An attachment object containing the attributes ```Filename```, ```ContentType```, ```Content```. The content has to be base64 encoded.|attachment object|```"MyAttachment": [ {     "Filename": "test.pdf", "ContentType": "application/pdf", "Content": "..." } ]```|
|```CIClassReference```|A reference to another Config Item|numeric ID of the referenced Config Item|```"ReferencedCI": 612```|
|```Contact```|A reference to a contact|ContactID|```"MyContact": 123```|
|```Organisation```|A reference to an organisation|OrganisationID|```"MyOrganisation": 456```|
|```Date```|A date value in the form "```YYYY-MM-DD```"|string|```"MyDate": "2018-08-28"```|
|```DateTime```|A date+time value in the form "```YYYY-MM-DD HH24:MI:SS```"|string|```"MyDateTime": "2018-08-28 09:23:58"```|
|```Dummy```|An empty object to create sub-structures|sub-structure|```"MyDummy": {}```|
|```GeneralCatalog```|A reference to a GeneralCatalog item|numeric ID of the GeneralCatalog item|```"MyGeneralCatalogItem": 123```|
|```TextArea```|A multi-line text|string|```"MyTextArea": "This\nis\njust\na\ntest."```|
|```Text```|A single-line text|string|```"MyText": "This is just a test."```|



