Feature: GET request to the /tickets resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing tickets
    Given 8 of tickets
    When I query the collection of tickets
    Then the response code is 200
#    Then the response object is TicketCollectionResponse
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with filter
    Given 4 of tickets 
    When I query the collection of tickets with filter of "test ticket for filter"
    Then the response code is 200 
    And the response contains the following items of type Ticket
      | Title                  |
      | test ticket for filter |
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with filter contain
    Given 8 of tickets
    When I query the collection of tickets with filter contains of "given"
    Then the response code is 200 
    And the response contains the following items of type Ticket
      | Title                                 |
      | test ticket given for unknown contact |
    When delete all this tickets
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing tickets with limit
    Given 8 of tickets
    When I query the collection of tickets with limit 4
    Then the response code is 200
    And the response contains 4 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing tickets with sorted
    Given 8 of tickets
    When I query the collection of tickets with sorted by "Ticket.-Title:textual" 
    Then the response code is 200
#    Then the response content is
    And the response contains 8 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with offset
    Given 8 of tickets
    When I query the collection of tickets with offset 4
    Then the response code is 200
    And the response now contains 8 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with limit and offset
    Given 8 of tickets
    When I query the collection of tickets with limit 26 and offset 2
    Then the response code is 200
    And the response now contains 0 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with sorted, limit and offset
    Given 8 of tickets
    When I query the collection of tickets with sorted by "Ticket.-Title:textual" limit 38 and offset 1
    Then the response code is 200
#    And the response now contains 5 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets with multiplesort (prio and queue)
    Given 20 of tickets
    When I query the collection of tickets with multiplesort by "Ticket.PriorityID:numeric,Ticket.QueueID:numeric"
    Then the response code is 200
#    And the response contains 35 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing tickets searchlimit
    Given 80 of tickets
    When I query the collection of tickets 55 searchlimit
    Then the response code is 200
    And the response contains 55 items of type "Ticket"
    When delete all this tickets
    Then the response code is 204
    And the response has no content
        
  Scenario: get the list of existing tickets searchlimit object
    Given 80 of tickets  
    When I query the collection of tickets 35 searchlimit object
    Then the response code is 200
    And the response contains 35 items of type "Ticket"        
    When delete all this tickets
    Then the response code is 204
    And the response has no content


    
    
     