Feature: GET request to the /system/ticket/states/:TicketStateID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing ticketstates
    When I query the collection of ticketstates
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse

  Scenario: get the list of existing ticketstates with filter
    When I query the collection of ticketstates with filter of closed
    Then the response code is 200
#   And the response object is TicketStateCollectionResponse
    And the response contains the following items of type TicketState
      | Name   | ValidID |
      | closed | 1       |   
    
  Scenario: get the list of existing ticketstates with limit
    When I query the collection of ticketstates with a limit of 2
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse 
    And the response contains 2 items of type "TicketState" 
    
  Scenario: get the list of existing ticketstates with offset
    When I query the collection of ticketstates with offset 2
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse 
    And the response contains 5 items of type "TicketState"
    
  Scenario: get the list of existing ticketstates with limit and offset
    When I query the collection of ticketstates with limit 2 and offset 1
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse 
    And the response contains 2 items of type "TicketState"
    
  Scenario: get the list of existing ticketstates with sorted
    When I query the collection of ticketstates with sorted by "State.-Name:textual" 
    Then the response code is 200
    And the response contains 7 items of type "TicketState"
    And the response contains the following items of type TicketState
      | Name               |
      | new                |
      | open               |
      | pending reminder   |
      | closed             |
      | pending auto close |
      | removed            |
      | merged             |

       
    
  Scenario: get the list of existing ticketstates with sorted, limit and offset
    When I query the collection of ticketstates with sorted by "TicketState.-Name:textual" limit 2 and offset 1
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse 
    And the response contains 2 items of type "TicketState"
    
    
    
    
    
    
     
