Feature: POST request to the /system/roles/:RoleID/userids resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: assign user to role
    Given a user
    When I assign the user to RoleID 1
    Then the response code is 201
    Then the response object is RoleUserIDPostResponse
