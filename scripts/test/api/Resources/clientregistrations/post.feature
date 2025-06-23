Feature: POST request /clientregistration resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a clientregistration
    When added a clientregistration
    Then the response code is 201
    Then the response object is ClientRegistrationPostResponse
    When I delete this clientregistration
    Then the response code is 204
    And the response has no content

  Scenario: added a clientregistration ohne authorization
    When added a clientregistration ohne authorization
Then the response content is
    Then the response code is 201
