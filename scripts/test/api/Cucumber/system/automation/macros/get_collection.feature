Feature: GET request to the /system/automation/macros resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation macros
    Given a automation macro
    Then the response code is 201 
    When I query the collection of automation macros
    Then the response code is 200 
    When delete all this automation macros
    Then the response code is 204
    And the response has no content     
