Feature: POST request to the /session/markobjectasseen resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a session markobjectasseen
    When I create a session markobjectasseen
    Then the response code is 204


