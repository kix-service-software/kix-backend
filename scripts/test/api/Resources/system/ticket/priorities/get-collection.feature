Feature: GET request to the /system/ticket/priorities resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing ticket priorities
    When I query the collection of ticket priorities
    Then the response code is 200
    And the response object is PriorityCollectionResponse

  Scenario: get the list of existing ticket priorities with filter
    When I query the collection of ticket priorities with filter of "2 high"
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains the following items of type Priority
      | Name   | ValidID |
      | 2 high | 1       |

  Scenario: get the list of existing ticket priorities with limit
    When I query the collection of ticket priorities with a limit of 4
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains 4 items of type "Priority"
    
  Scenario: get the list of existing ticket priorities with offset
    When I query the collection of ticket priorities with offset 2
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains 3 items of type "Priority"
    
  Scenario: get the list of existing ticket priorities with limit and offset
    When I query the collection of ticket priorities with limit 2 and offset 2
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains 2 items of type "Priority"    
    
  Scenario: get the list of existing ticket priorities with sorted
    When I query the collection of ticket priorities with sorted by "Priority.-Name:textual" 
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains 5 items of type "Priority"
    And the response contains the following items of type Priority
      | Name        |
      | 5 very low  |
      | 4 low       |
      | 3 normal    |
      | 2 high      |
      | 1 very high |
                      
  Scenario: get the list of existing ticket priorities with sorted, limit and offset
    When I query the collection of ticket priorities with sorted by "PriorityAddress.-NameEmailAddress:textual" limit 2 and offset 1
    Then the response code is 200
    And the response object is PriorityCollectionResponse
    And the response contains 2 items of type "Priority"
    
    
    
    
