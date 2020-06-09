Feature: PATCH request to the /session/user/preferences/:UserPreferenceID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a session user preference
    Given a session user preference
    Then the response code is 201
    When I update this session user preference
    Then the response code is 200
    When I delete this session user preference
    Then the response code is 204

