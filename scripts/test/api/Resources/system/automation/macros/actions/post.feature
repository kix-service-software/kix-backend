Feature: POST request to the /system/automation/macros/:MacroID/actions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a automation macro action
    Given a automation macro without action
    Then the response code is 201
    When I create a automation macro action 
    Then the response code is 201
    And the response object is MacroActionPostPatchResponse
    When I delete this automation macro action
    Then the response code is 204
    When I delete this automation macro
    Then the response code is 204

  Scenario: create a automation macro action (error)
    Given a automation macro without action
    Then the response code is 201
    When I create a automation macro action with no ContactEmailOrID
    Then the response code is 400
    And the response object is Error
    And the error code is "Object.UnableToCreate"
    And the error message is "MacroAction config is invalid (Required parameter "ContactEmailOrID" missing!)!"
    When I delete this automation macro
    Then the response code is 204

