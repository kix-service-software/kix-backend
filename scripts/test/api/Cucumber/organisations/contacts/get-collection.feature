 Feature: GET request to the /organisations/:OrganisationID/contacts resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing organisation contacts
    Given a organisation
    Then the response code is 201
    Given a contact
    Then the response code is 201 
    When I query the collection of organisation contacts with this OrganisationID  
    Then the response code is 200
    And the response contains the following items of type Organisation
    When I delete this contact
    Then the response code is 204
    And the response has no content
    When I delete this organisation
    Then the response code is 204
    And the response has no content
