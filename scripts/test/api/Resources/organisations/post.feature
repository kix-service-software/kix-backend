Feature: POST request /organisations resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a organisation
    When added a organisation
    Then the response code is 201
    Then the response object is OrganisationPostPatchResponse
    When I delete this organisation
    Then the response code is 204

  Scenario: added a organisation
    When added a organisation without number
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"
    And the error message is "Cannot create organisation. Another organisation with same number already exists."