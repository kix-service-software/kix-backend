Feature: POST request to the /system/roles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a role
    When I create a role
    Then the response code is 201   
    Then the response object is RolePostPatchResponse
    When I delete this role
    Then the response code is 204
    Then the response has no content
    
