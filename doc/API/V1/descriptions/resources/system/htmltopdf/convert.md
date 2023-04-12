#### Convert

This ressources don't support default includes, expands, limits. Only specific queries will be allowed.

##### Supported Queries

|Query|Description|Required|
|-|-|-|
|```TemplateID```|Is required to get the template to be used. (Alternatively ```TemplateName``` can be used)| x |
|```TemplateName```|Is required to get the template to be used. (Alternatively ```TemplateID``` can be used)| x |
|```IdentifierType```|Is required to set the identification type. ```IDKey``` or ```NumberKey``` can be set.|x|
|```IdentifierIDorNumber```|Is required to set the identifier. This depends on what is set in ```IdentifierType```. ```IDKey``` is the ID of the ticket and if ```NumberKey``` it would be the ticket number.|x|
|```Expands```|This ```Expand``` means the data expansion of the object which is applied to the template. (as array or comma separated string)|-|
|```Filters```|Optional filters can be used to restrict certain extensions (format as JSON).|-|
|```Allows```|Defines a whitelist that only shows the attributes that are named in it. If no allow is specified, everything appears.The Allows overwrites the Allow of the specified table in the template.(format as JSON) |-|
|```Ignores```|Defines a blacklist that removes the attributes that made it through the whitelist. If no ignore is set, the final result is the result of the allow application. If both are emptied, all information from the objects is displayed. Ignores overwrites the Ignore of the specified table in the template.(format as JSON) |-|
|```Filename```|user-specific filename of the PDF. It is possible to use placeholders, including special ones.|-|


##### Special Placeholders

|Placeholder|Description|
|-|-|
|```<Current_Time>```| Returns the current date |
|```<Current_User>```| Returns the full name of the trigger of the print job. |
|```<Count>```|Returns the current count. (Basically used for article numbering)|
|```<TIME_YYMMDD_hhmm>```| Returns the current time in the format ```YYYYMMDD_hhmm```|
|```<TIME_YYMMDD>```| Returns the current time in the format ```YYYYMMDD```|
|```<TIME_YYMMDDhhmm>```| Returns the current time in the format ```YYYYMMDDhhmm``` |

##### Filters
###### Syntax

Filters can only be applied where in the template ```Data``` is contained in the block and exists as an object. (e.g. ticket, article)
Only attributes that the object can supply can be filtered.

```
{
  "<Data-Object>": {
     "AND": [
      {
        "Field": "<Attribute>",
        "Type": "<EQ|CONTAINS>",
        "Value": "<ARRAY|STRING>"
      }
    ]
  }
}
```

###### Example

A ticket should only take into account the articles that are visible to the customer.

```
{
  "Article": {
    "AND": [
      {
        "Field": "CustomerVisible",
        "Type": "EQ",
        "Value": "1"
      }
    ]
  }
}
```

##### Allows/Ignores
###### Syntax

In order to address the respective table, its ```Reference ID``` is required first. This can be found in the template structure. If the ID is known, a JSON can be created that contains the attributes to be restricted. There are two options for the restriction:
* By using the shortcut ```KEY```, the entire attribute will be ignored or displayed without further checking.
* By using a regular expression, the values of an attribute can be checked. If the respective value applies, the attribute is ignored or displayed. The regular expression is freely selectable. However, it must not contain ```KEY``` because ```KEY``` is the keyword for the entire attribute.

```
{
  "Reference-ID": {
     "Attribute": "KEY",
     "Attribute": "regex"
  }
}
```

###### Example

```
{
   "ArticleMeta": {
      "Channel": "KEY",
      "From": "cape-it.de$"
   }
}
```