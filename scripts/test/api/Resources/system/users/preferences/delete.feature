Feature: DELETE request to the /system/users/:UserID/preferences/:PreferenceID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this user preferences
    Given a user
    Given a user preference
    When I delete this user preference
    Then the response code is 204
    And the response has no content
