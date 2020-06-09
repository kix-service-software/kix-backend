Feature: PATCH request to the /system/ticket/types/:TypeID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a tickettype
    Given a tickettype
      | Name                   | ValidID | Comment    |
      | __GET_RANDOM_STRING__  |   1     | TicketType |
    Then the response code is 201 
    When I update this tickettype
      | Name                        | ValidID | Comment    |
      | Update__GET_RANDOM_STRING__ |   1     | TicketType |
    Then the response code is 200
    And the response object is TicketTypePostPatchResponse
    When I delete this tickettype
    Then the response code is 204


