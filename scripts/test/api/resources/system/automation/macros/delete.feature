Feature: DELETE request to the /system/automation/macros/:MacroID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this automation macro
    Given a automation macro
    Then the response code is 201
    When I delete this automation macro
    Then the response code is 204
    And the response has no content
