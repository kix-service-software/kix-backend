Feature: POST request /organisations resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a organisation
     When added a organisation
    Then the response object is OrganisationPostPatchResponse
    When I delete this organisation
    Then the response code is 204

