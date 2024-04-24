Feature: GET request to the /system/roles/permissiontypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of permissiontypes 
    When I query the collection of roles permissiontypes
    Then the response code is 200
    And the response object is PermissionTypeCollectionResponse

  Scenario: get the list of permissiontypes with filter 
    When I query the collection of roles permissiontypes with filter of Object
    Then the response code is 200  
    And the response contains the following items of type PermissionType
      | Name          | Comment                                                                                                        |
      | Object | Permission type that restricts access of objects based on their property values (i.e. tickets with QueueID=1). |

  Scenario: get the list of permissiontypes with limit 
    When I query the collection of roles permissiontypes with a limit of 2
    Then the response code is 200
    And the response contains 2 items of type "PermissionType"