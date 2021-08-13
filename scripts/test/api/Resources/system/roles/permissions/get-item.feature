Feature: GET request to the /system/roles/:RoleID/permissions/:PermissionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get a specific permission
    Given a role
    Given a permission
    When I get this permission
    Then the response code is 200
    When I delete this permission
    Then the response code is 204
    When I delete this role
    Then the response code is 204
    And the response has no content