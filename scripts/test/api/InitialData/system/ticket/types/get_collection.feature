Feature: GET request to the /system/ticket/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: check is the existing tickettypes are consistent with the delivery defaults
    When I query the collection of tickettypes
    Then the response code is 200
    And the response object is TicketTypeCollectionResponse
    Then the response contains 3 items of type "TicketType"
    Then the response contains the following items of type TicketType
      | Name                   |
      | Unclassified           |
      | Incident               |
      | Service Request        |

