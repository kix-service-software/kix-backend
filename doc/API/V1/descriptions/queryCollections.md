When querying collections you can use some special query parameters to influence the given response. Those special parameters are (in order of execution)

* [search](#searching-objects)
* [filter](#filtering-results)
* [sort](#sorting-results)
* [offset](#using-list-offsets)
* [limit](#limiting-results)

### searching objects

Some collection resources support the query parameter ```search``` which means that you can define which attribute will be searched in the backends datasources. In constract to the optional [```filter```](#filtering-results) the ```search``` function is based on the abilities of the core modules and the underlying datasources (DBMS) with their relationships. Therefore not everything that can be done with [```filters```](#filtering-results) can be done with a ```search``` function. But since searches are executed at datasource level it can improve the performance of a request significantly.

Usage in URL:
```
    .../<resource>?search={...}
```

The search definition is a JSON object identical to a [```filter```](#filtering-results) function. Please see the [```filter```](#filtering-results) function for a detailled description of this structure.

If a collection resource supports the ```search``` function and what exactly can be searched (fields/object attributes, operators, etc.) can be found in the description of the relevant resource.

### filtering results

You can use an optional ```filter``` function to filter the items in the response. The ```filter``` function will be execute at API level and therefore is a lot more powerful in terms of complexity than the [```search```](#searching-objects) function. Also the ```filter``` function is available for all collection resources. Since it works on all the data coming back from the datasource level please carefully tune the combination of [```search```](#searching-objects) and ```filter``` to achieve the best performance.

Usage in URL:
```
    .../<resource>?filter={...}
```

The filter definition is a JSON object in the following form:
```
    {
        "<Object>": {
            "AND": [
                {
                    "Field":     "<Fieldname>",
                    "Operator":  "<Operator>",
                    "Value":     "<Value>"[,]
                    ["Type":     "<Type>",]
                    ["Not":      <Not>,]
                },
                ...next field...
            ],
            "OR": [
                {
                    "Field":     "<Fieldname>",
                    "Operator":  "<Operator>",
                    "Value":     "<Value>"[,]
                    ["Type":     "<Type>",]
                    ["Not":      <Not>,]
                },
                ...next field...
            ]
        }
    }
```

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```|X|The object in the JSON response to be filtered.|
|```<Fieldname>```|X|The attribute in each item of the response to be filtered.|
|```<Operator>```|X|The compare operator to be used.|
|```<Value>```|X|The value to compare to. Filters are working case-insensitive. If the value starts with a ```$``` character it will be interpreted as a reference to another attribute and the actual value will be taken from the referenced attribute.|
|```<Type>```||The type of data that should be used to compare the value. If not given, the value will be interpreted as a string.|
|```<Not>```||To negate the comparison set this to ```true```.|

Supported types:

|Type|Description|
|-|-|
|```STRING```|The value will be treated as a text of ASCII characters.|
|```NUMERIC```|The value will be treated as a number (integer or float).|
|```DATE```|The value will be treated as a date of the form ```YYYY-MM-DD```|
|```DATETIME```|The value will be treated as a date + time combination of the form ```YYYY-MM-DD HH24:MI:SS```|

Supported operators:

|Operator|Meaning|Valid for datatypes|Description|
|-|-|-|-|
|```EQ```|equal to|all|The data value must be exactly identical to the filter value.|
|```NE```|not equal to|all|The data value must not be identical to the filter value.|
|```LT```|less than|NUMERIC, DATE, DATETIME|The data value must be less than the filter value.|
|```LTE```|less than or equal|NUMERIC, DATE, DATETIME|The data value must be less than or equal to the filter value.|
|```GT```|greater than|NUMERIC, DATE, DATETIME|The data value must be greater than the filter value.|
|```GTE```|greater than or equal|NUMERIC, DATE, DATETIME|The data value must be greater than or equal to the filter value.|
|```IN```|exists in list|all|The data value must be one of the given list of filter values. This is identical to separate OR filters with EQ operators for each filter value|
|```CONTAINS```|contains a pattern|STRING|The filter value is contained in the data value at any position.|
|```STARTSWITH```|starts with a pattern|STRING|The data value starts with the filter value.|
|```ENDSWITH```|ends with a pattern|STRING|The data value end with the filter value.|
|```LIKE```|matches pattern|STRING|The data value matches the filter value which represents a pattern. The wildcard ```*``` can be used multiple times. Without a wildcard the LIKE operator works like the EQ operator.|


### sorting results

### using list offsets

### limiting results