Feature: POST request to the /system/automation/execplans resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a automation execplan
    When I create a automation execplan 
    Then the response code is 201
    And the response object is ExecPlanPostPatchResponse
    When I delete this automation execplan
    Then the response code is 204

