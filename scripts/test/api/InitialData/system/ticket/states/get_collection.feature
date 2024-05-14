Feature: GET request to the /system/ticket/states/:TicketStateID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario Outline: check is the existing ticketstates are consistent with the delivery defaults
    When I query the collection of ticketstates
    Then the response code is 200
    Then the ticketstates output is "<Name>"

    Examples:
      | Name                   |
      | new                    |
      | open                   |
      | pending reminder       |
      | closed                 |
      | pending auto close     |
      | removed                |
      | merged                 |

  Scenario: check is the existing ticketstates are consistent with the delivery defaults
    When I query the collection of ticketstates
    Then the response code is 200
#    And the response object is TicketStateCollectionResponse
    Then the response contains 7 items of type "TicketState"
    Then the response contains the following items of type TicketState
      | Name                   | ValidID |
      | new                    | 1       |
      | open                   | 1       |
      | pending reminder       | 1       |
      | closed                 | 1       |
      | pending auto close     | 1       |
      | removed                | 1       |
      | merged                 | 1       |
    
    
    