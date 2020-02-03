Feature: GET request to the /system/automation/execplans resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an automation execplan
    Given a automation execplan for get
    Then the response code is 201    
    When I get this automation execplan
    Then the response code is 200
    And the attribute "ExecPlan.Name" is "new execution plan for get"
    When I delete this automation execplan
    Then the response code is 204


    
