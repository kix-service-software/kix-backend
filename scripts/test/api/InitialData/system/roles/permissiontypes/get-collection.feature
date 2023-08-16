Feature: GET request to the /system/roles/permissiontypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of permissiontypes 
    When I query the collection of roles permissiontypes
    Then the response code is 200
    And the response contains 4 items of type "PermissionType"
    And the response contains the following items of type PermissionType   
      | Name          | Comment                                                                                                        |
      | Resource      | Permission type that corresponds with a API resource.                                                          |
      | Object        | Permission type that restricts access of objects based on their property values (i.e. tickets with QueueID=1). |
      | Property      | Permission type that restricts access on object properties (QueueID in tickets).                               |
      | Base::Ticket  | Permission type for core object dependency Queue->Ticket.                                                      |

