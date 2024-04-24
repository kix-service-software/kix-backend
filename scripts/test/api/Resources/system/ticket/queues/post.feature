Feature: POST request to the /system/ticket/queues resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a ticket queue
    When added a ticket queue
    Then the response code is 201
    Then the response object is QueuePostPatchResponse
    When I delete this ticket queue
    Then the response code is 204

