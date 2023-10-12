Feature: PATCH request to the /tickets/:TicketID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a ticket
    Given a ticket
    When I update this ticket
    Then the response code is 200
# Then the response object is TicketPostPatchResponse
    When I delete this ticket
    Then the response code is 204

  Scenario: update a ticket do not changed placeholder
    Given a ticket
    When I update this ticket with placeholder
    Then the response code is 200
    When I get this ticket with include article
    Then the response code is 200
    And the response contains the following article attributes
      | # Body                                                                                                                                                  |
      | Calendar: , BusinessTimeDeviaton: , TargetTime: , KIX_CONFIG_Ticket::Hook:,KIX_CONFIG_PGP::Key::Password: ,KIX_CONFIG_ContactSearch::UseWildcardPrefix: |
    When I delete this ticket
    Then the response code is 204
