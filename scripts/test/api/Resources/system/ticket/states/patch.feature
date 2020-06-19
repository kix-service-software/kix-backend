Feature: PATCH request to the /system/ticket/ticketstates/:TicketStateID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a ticketstate
    Given a ticketstate
    When I update this ticketstate
    Then the response code is 200
    And the response object is TicketStatePostPatchResponse
    When I delete this ticketstate
    Then the response code is 204

