Feature: GET request to the /system/automation/execplans/types/:ExecPlanType resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an automation execplan type
    Given a automation execplan
    Then the response code is 201
    Given a automation execplan    
    When I get this automation execplan type "EventBased"
    Then the response code is 200
    And the attribute "ExecPlanType.Description" is "Allows an event based execution of automation jobs. At least one event must be configured."
    When I delete this automation execplan
    Then the response code is 204


    
