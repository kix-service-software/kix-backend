 Feature: GET request to the /system/sessions/:Token resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing session
    When I get this session
    Then the response code is 200
    And the attribute "Session.TokenType" is "Normal"

