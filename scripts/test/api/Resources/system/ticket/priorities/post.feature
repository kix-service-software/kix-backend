Feature: POST request to the /system/ticket/priorities resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a ticket priority
    When I create a ticket priority with 
    Then the response object is PriorityPostPatchResponse
    Then the response code is 201
    When I delete this ticket priority
    Then the response code is 204

