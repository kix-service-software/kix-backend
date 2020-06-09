Feature: DELETE request to the /system/roles/:RoleID/userids/:UserID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete role assignment
    When I delete role assignment with roleid 1
    Then the response code is 204
    And the response has no content

