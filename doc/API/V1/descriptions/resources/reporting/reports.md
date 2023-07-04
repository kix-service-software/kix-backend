#### Reports

##### Creating a report

Each report contains a ```Config``` property. All required parameters defined in the report definition have to be present here with a value as well as all output formats the report should be created for.

Here is an example of such a parameters property:

    ``` json
    {
        "Config": {
            "Parameters": {
                "NameFilter": "inv"
            },
            "OutputFormats": ["CSV"]
        }
    }
    ```

The ```OutputFormats``` property can only contain output formats defined in the report definition.

This resource supports a special ```search``` property

|Search|Description|
|-|-|
|```DefinitionID```| Restricts the database query to the given DefinitionID. Only the operator "EQ" is supported.|
