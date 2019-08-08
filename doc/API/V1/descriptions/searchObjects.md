Some collection resources support the query parameter ```search``` which means that you can define the properties of objects that will be searched in the backends datasources. In contrast to the optional [```filter```](#filter_results) the ```search``` function depends on the abilities of the core modules and the underlying datasources (DBMS) with their relationships. Therefore not everything that can be done with [```filters```](#filter_results) can be done with a ```search``` function. But since searches are executed at datasource level they can improve the performance of a request significantly.

** Usage in URL **
``` bash
    .../<resource>?search={...}
```

The search definition is a JSON object identical to a [```filter```](#filter_results) function. Please see the [```filter```](#filter_results) function for a detailed description of this structure.

Whether a collection resource supports the ```search``` function and which properties can be searched (fields/object attributes, operators, etc.) can be found in the description of the relevant resource.