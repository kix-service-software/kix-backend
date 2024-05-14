Feature: GET request to the /system/roles/:RoleID/permissions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing permissions
    When I query the collection of permissions with roleid 1
    Then the response code is 200
   And the response object is PermissionCollectionResponse

  Scenario: get the list of existing permissions filtered
    When I query the collection of permissions with roleid 10 and filter target "/system/cmdb/classes"
    Then the response code is 200
    And the response object is PermissionCollectionResponse
    And the response contains the following items of type Permission
      | Target               |
      | /system/cmdb/classes |