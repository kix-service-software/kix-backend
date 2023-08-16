Feature: PATCH request to the /system/automation/macros/:MacroID/actions/:MacroActionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a automation macro action
    Given a automation macro without action
    Given a automation macro action
    When I update this automation macro action
    Then the response code is 200
    And the response object is MacroActionPostPatchResponse
    When I delete this automation macro action
    Then the response code is 204
    When I delete this automation macro
    Then the response code is 204

