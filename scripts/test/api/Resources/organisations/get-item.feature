 Feature: GET request to the /organisations/:OrganisationID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing organisation
    Given a organisation with Number "K12345678_test"
    When I get this organisation
    Then the response code is 200
    And the attribute "Organisation.Name" is "Test Organisation_cu"
    When I delete this organisation
    Then the response code is 204
    And the response has no content






