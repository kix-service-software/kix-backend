Feature: GET request to the /tickets/checklist resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing ticket checklist
    Given a ticket
    Then the response code is 201
    When I create a ticket checklist
    Then the response code is 201
    When I query the collection of ticket checklist
    Then the response code is 200
#    And the response object is ConfigItemCollectionResponse
    When I delete this ticket checklist
    Then the response code is 204
    And the response has no content

