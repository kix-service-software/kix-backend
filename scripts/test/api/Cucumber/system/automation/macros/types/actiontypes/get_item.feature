Feature: GET request to the /system/automation/macros/types/:MacroType/actiontypes/:MacroActionType resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an automation macro type actiontype
    When I query the collection of automation macro type "Ticket" actiontype "StateSet"
    Then the response code is 200 


    
