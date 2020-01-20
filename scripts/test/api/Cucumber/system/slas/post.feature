Feature: POST request to the /system/slas resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a sla
    When I create a sla 
    Then the response code is 201
#    Then the response object is SlaPostPatchResponse
    When I delete this sla
    Then the response code is 204

