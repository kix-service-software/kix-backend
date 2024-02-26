Feature: GET request to the /system/ticket/priorities resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario Outline: check is the existing priorities are consistent with the delivery defaults
    When I query the collection of ticket priorities
    Then the response code is 200
    Then the priorities output is "<Name>"

    Examples:
      | Name        |
      | 5 very low  |
      | 4 low       |
      | 3 normal    |
      | 2 high      |
      | 1 very high |

  Scenario: check is the existing priorities are consistent with the delivery defaults
    When I query the collection of ticket priorities
    Then the response code is 200
#    And the response object is PriorityCollectionResponse
    Then the response contains 5 items of type "Priority"
    Then the response contains the following items of type Priority
      | Name        | ValidID |
      | 5 very low  | 1       |
      | 4 low       | 1       |
      | 3 normal    | 1       |
      | 2 high      | 1       |
      | 1 very high | 1       |
