Feature: DELETE request /contacts/:ContactID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this contact
    Given a organisation
    Given a contact
    When I delete this contact
    Then the response code is 204
    And the response has no content
    When I delete this organisation
    Then the response code is 204
    And the response has no content
    
    