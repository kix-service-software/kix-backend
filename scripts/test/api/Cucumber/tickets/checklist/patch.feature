Feature: PATCH request to the /tickets/:TicketID/checklist/:ChecklistItemID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a ticket checklist
    Given a ticket
    Then the response code is 201
    Given a ticket checklist
    Then the response code is 201
    When I update this ticket checklist
    Then the response code is 200
    When I delete this ticket checklist
    Then the response code is 204
    When I delete this ticket
    Then the response code is 204
    And the response has no content

