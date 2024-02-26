Feature: GET request to the /system/ticket/types resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing tickettypes
    When I query the collection of tickettypes
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse

  Scenario: get the list of existing tickettypes with filter
    When I query the collection of tickettypes with filter of Incident
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse
    And the response contains the following items of type TicketType
      | Name     | ValidID |
      | Incident | 1       |

  Scenario: get the list of existing tickettypes with limit
    When I query the collection of tickettypes with a limit of 3
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse
    And the response contains 3 items of type "TicketType"

  Scenario: get the list of existing tickettypes with offset
    When I query the collection of tickettypes with offset 1
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse
    And the response contains 2 items of type "TicketType"

  Scenario: get the list of existing tickettypes with sorted
    When I query the collection of tickettypes with sorted by "TicketType.-Name:textual"
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse
    And the response contains 3 items of type "TicketType"
    And the response contains the following items of type TicketType
      | Name            |
      | Unclassified    |
      | Service Request |
      | Incident        |

  Scenario: get the list of existing tickettypes with sorted, limit and offset
    When I query the collection of tickettypes with sorted by "TicketType.-Name:textual" limit 2 and offset 2
    Then the response code is 200
#    And the response object is TicketTypeCollectionResponse
    And the response contains 1 items of type "TicketType"
    And the response contains the following items of type TicketType
      | Name            |
      | Service Request |






