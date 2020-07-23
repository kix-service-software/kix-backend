Feature: GET request to the /system/ticket/priorities/:PriorityID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing ticket priority
    When I get the ticket priority with ID 3
    Then the response code is 200
    And the response object is PriorityResponse
    And the attribute "Priority.Name" is "3 normal"

    
