Feature: POST request to the /session/user/preferences resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a session user preference
    When I create a session user preference
    Then the response code is 201
    When I delete this session user preference
    Then the response code is 204

