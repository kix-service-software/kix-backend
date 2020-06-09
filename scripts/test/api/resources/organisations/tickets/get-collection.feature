 Feature: GET request to the /organisations/:OrganisationID/tickets resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing organisation tickets
    Given a organisation
    Then the response code is 201
    Given a ticket for organisation test
    Then the response code is 201 
    When I query the collection of organisation tickets with this OrganisationID  
    Then the response code is 200
    And the response contains the following items of type Organisation
#    And the response object is OrganisationCollectionResponse    
    When I delete this ticket
    Then the response code is 204
    And the response has no content
    When I delete this organisation
    Then the response code is 204
    And the response has no content
