Feature: GET request to the /tickets resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing tickets
    Given 8 of tickets
    When I query the collection of tickets
    Then the response code is 200
    When delete all this tickets
    Then the response code is 204
    And the response has no content
    When I query the collection of tickets

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
    When I query the collection of tickets

  Scenario: get the list of existing tickets with filter contain
    Given 8 of tickets
    When I query the collection of tickets with filter contains of "cont"
    Then the response code is 200 
    And the response contains the following items of type Ticket
      | Title                           |
      | test ticket for unknown contact |
    When delete all this tickets
    Then the response code is 204
    And the response has no content
    When I query the collection of tickets

  Scenario: get the list of existing tickets with filter in
    Given 8 of tickets
    When I query the collection of tickets with AND-filter of Title "cont" and PriorityID 2 and QueueID 2
    Then the response code is 200 
    And the response contains the following items of type Ticket
      | Title                           |
      | test ticket for unknown contact |
    When delete all this tickets
    Then the response code is 204
    And the response has no content
    When I query the collection of tickets
    
  Scenario: get the list of existing tickets with limit
    Given 8 of tickets
    When I query the collection of tickets with limit 4
    Then the response code is 200
    And the response contains 4 items of type Ticket  
    When delete all this tickets
    Then the response code is 204
    And the response has no content  
    When I query the collection of tickets
    
  Scenario: get the list of existing tickets with sorted
    Given 8 of tickets
    When I query the collection of tickets with sorted by "Ticket.-Title:textual" 
    Then the response code is 200
    And the response contains 8 items of type Ticket  
    When delete all this tickets
    Then the response code is 204
    And the response has no content       
    When I query the collection of tickets
    
  Scenario: get the list of existing tickets with offset
    Given 8 of tickets
    When I query the collection of tickets with offset 4
    Then the response code is 200
    And the response contains 4 items of type Ticket  
    When delete all this tickets
    Then the response code is 204
    And the response has no content   

#  Scenario: get the list of existing tickets with limit and offset
#    Given 8 of tickets
#    When I query the collection of tickets with limit 26 and offset 2
#    Then the response code is 200
#    And the response contains 2 items of type Ticket  
#    When delete all this tickets
#    Then the response code is 204
#    And the response has no content   
#    When I query the collection of tickets
    
#   Scenario: get the list of existing tickets with sorted, limit and offset
#    Given 8 of tickets
#    When I query the collection of tickets with sorted by "Ticket.-Title:textual" limit 38 and offset 1
#    Then the response code is 200
#    And the response contains 2 items of type Ticket  
#    When delete all this tickets
#    Then the response code is 204
#    And the response has no content      
#    When I query the collection of tickets

    
    
     