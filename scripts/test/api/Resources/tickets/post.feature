Feature: POST request to the /tickets resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a ticket
    When I create a ticket
    Then the response code is 201
    Then the response object is TicketPostPatchResponse
    When I delete this ticket
    Then the response code is 204

  Scenario: create a ticket no validate
    When I create a complete ticket
    Then the response code is 400
    And the response object is Error
    And the error code is "Validator.Failed"
    And the error message is "Validation of attribute From failed (someone.com)!"

  Scenario: create a ticket do not changed placeholder
    When I create a ticket placeholder
    Then the response code is 201
    Then the response object is TicketPostPatchResponse
    When I get this ticket with include article
    Then the response code is 200
    And the response contains the following article attributes
      | # Body                                                                                                                                                  |
      | Calendar: , BusinessTimeDeviaton: , TargetTime: , KIX_CONFIG_Ticket::Hook:,KIX_CONFIG_PGP::Key::Password: ,KIX_CONFIG_ContactSearch::UseWildcardPrefix: |
    When I delete this ticket
    Then the response code is 204

  Scenario: create a ticket no organisation
    When I create a complete ticket no organisation
    Then the response code is 201
    When I get this ticket
    Then the response code is 200
    And the response contains the following article attributes
      | ContactID | LockID | QueueID | OrganisationID | TypeID | StateID | PendingTimeUnix | UntilTime | ResponsibleID | PriorityID | OwnerID |
      | 1         | 1      | 1       |                | 1      | 1       | 0               | 0         | 1             | 3          | 1       |
    When I delete this ticket
    Then the response code is 204





