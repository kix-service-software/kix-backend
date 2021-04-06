#### Report Definitions

##### Creating a report definition

Each report definition contains a ```config``` property. This constists of upto three separate configurations for
* the report type
* the parameters used in the report type configuration (this is optional, if no parameters are used)
* the output formats

Here is an example of such a config with parameters for report type ```GenericSQL```:

    ``` json
    {
        "Config": {
            "DataSource": {
                "SQL": {
                    "any": "SELECT count(*) as Total FROM ticket WHERE type_id IN [${Parameters.TypeIDList}]"
                }
            },
            "Parameters": [
                {
                    "Name": "TypeIDList",
                    "Label": "Type Selection",
                    "Datatype": "NUMERIC",
                    "Description": "Please select the ticket types.",
                    "Required": 1,
                    "Multiple": 1,
                    "References": "TicketType.ID",
                    "Default": [0]
                }
            ],
            "OutputFormats": {
                "CSV": {
                    "Columns": ["Total"]
                }
            }
        }
    }
    ```

The contents of the ```DataSource``` section can be taken from the description of the data source (see resource ["datasources"](#reporting_datasources_get)).

The ```OutputFormats``` section has to contain all relevant options to configure the output formats that should be available for a report based on this definition. The possible configuration options can be found in the description of each output format (see resource ["outputformats"](#reporting_outputformats_get)).

**Defining parameters**

The goal of this parameter definition is to tell an API client what exactly to provide when creating a report. Additionally it helps GUI based API clients to determine what kind of GUI element is needed and in which order the parameters should be displayed (array index).

Each parameter used in the ```DataSource``` config, which should be given in the report creation, has to be defined in ```Parameters``` at least by a ```Name``` and a ```DataType```. The following table describes all possible config options for a parameter.

|Option|Required|Description|
|-|-|-|
|```Name```|X|The name of the parameter which will be used in the ```DataSource``` configuration.|
|```DataType```|X|The type of the data of this parameter. The following types are supported: STRING, NUMERIC, DATE, TIME, DATETIME|
|```Label```||The label to be displayed in a GUI environment. If the label is not defined, then the name should be used as the label.|
|```Description```||A describing text to explain the parameter.|
|```References```||A hint for a report creator (human or algorithm) what this parameter is all about, to make sure the correct thing is provided. Example: ```TicketType.ID```|
|```Multiple```||Set this to ```1``` if this parameter is an array of values.|
|```Required```||Set this to ```1``` if this parameter is required to be given in a report creation.|
|```ReadOnly```||Set this to ```1``` if this parameter is only a read only information when creating a report.|
|```Default```||The default value of the parameter, in case it's optional.|
|```PossibleValues```||The range of possible values to select from.|


**Using parameters**

How a parameter is used and defined, you can find in the example above. Simply write the name of the parameter in ```${Parameters.<Name>}```.

##### Supported Includes

This resource supports the following includes.

|Include|Description|
|-|-|
|```Reports```|Adds the list of reports for this report definition to the response. See resource ["reports"](#reporting_reports).|