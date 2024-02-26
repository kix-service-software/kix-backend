Feature: PATCH request to the /system/roles/:RoleID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a role
    Given a role
    When I update this role with
    Then the response code is 200
    And the response object is RolePostPatchResponse
    When I delete this role
    Then the response code is 204
