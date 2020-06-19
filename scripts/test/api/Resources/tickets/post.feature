Feature: POST request to the /tickets resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a ticket
    When I create a ticket
    Then the response code is 201
    When I delete this ticket
    Then the response code is 204

