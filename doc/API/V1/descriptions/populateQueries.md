### Query collections

When querying collections you can use some special functions to influence the resulting response. Those special functions are (in order of execution)

* [search](#search_objects)
* [offset](#limit_results)
* [limit](#limit_results)
* [filter](#filter_results)
* [sort](#sort_results)

### Query items

When requesting items there are also special functions to change the resulting response. Those special functions are (in order of execution)

* [fields](#select_fields)
* [include](#include_additional_information)
* [expand](#expand_referenced_objects)

Please note that when querying collections the collection resource uses the corresponding item resource to populate the data of each item to prepare the response. Therefore you can use those special functions in queries of the corresponding collection resource as well.
