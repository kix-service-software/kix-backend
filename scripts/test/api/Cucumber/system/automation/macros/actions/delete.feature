Feature: DELETE request to the /system/automation/macros/:MacroID/actions/:MacroActionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this automation macro action
    Given a automation macro without action
    Then the response code is 201 
    Given a automation macro action
    Then the response code is 201
    When I delete this automation macro action
    Then the response code is 204
    And the response has no content
    When I delete this automation macro
    Then the response code is 204
    And the response has no content