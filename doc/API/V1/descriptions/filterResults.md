You can use an optional ```filter``` function to filter the items in the response of collections. The ```filter``` function will be execute at API level and therefore is a lot more powerful in terms of complexity than the [```search```](#search_objects) function. Also the ```filter``` function is available for all collection resources. Since it works on all the data coming back from the datasource level please carefully tune the combination of [```search```](#search_objects) and ```filter``` to achieve the best performance.

** Usage in URL **
``` bash
    .../<resource>?filter={...}
```

The filter definition is a JSON object in the following form:
``` bash
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


** Explanation **

|Parameter|Required?|Description|
|-|:-:|-|
|```<Object>```|yes|The object in the JSON response to be filtered.|
|```<Fieldname>```|yes|The attribute in each item of the response to be filtered.|
|```<Operator>```|yes|The compare operator to be used.|
|```<Value>```|yes|The value to compare to. Filters are working case-insensitive. If the value starts with a ```$``` character it will be interpreted as a reference to another attribute and the actual value will be taken from the referenced attribute.|
|```<Type>```||The type of data that should be used to compare the value. If not given, the value will be interpreted as a string.|
|```<Not>```||To negate the comparison set this to ```true```.|

If both lists are given (AND and OR) they will be combines using a logical AND operation.


** Supported types **

|Type|Description|
|-|-|
|```STRING```|The value will be treated as a text of ASCII characters.|
|```NUMERIC```|The value will be treated as a number (integer or float).|
|```DATE```|The value will be treated as a date of the form ```YYYY-MM-DD```|
|```DATETIME```|The value will be treated as a date + time combination of the form ```YYYY-MM-DD HH24:MI:SS```|


** Supported operators **

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


** Example **

Return all users whose UserID isn't 1, 2 oder 3 and whose first name doesn't begin with their last name and whose email address doesn't end with "cape-it.de".

```
{
    "User": {
        "AND": [
            {
                "Field": "UserEmail",
                "Operation": "ENDSWITH",
                "Value": "cape-it.de"
            },
            {
                "Field": "UserID",
                "Operation": "IN",
                "Value": [ 1, 2, 3 ],
                "Type": "numeric"
            },
            {
                "Field": "UserFirstname",
                "Operation": "STARTSWITH",
                "Value": "$UserComment",
                "Not": true
            }
        ]
    ]
}
```