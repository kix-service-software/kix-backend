Feature: GET request to the /system/ticket/states/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing statetypes
    When I query the collection of statetypes
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse

  Scenario: get the list of existing statetypes with filter
    When I query the collection of statetypes with filter of removed
    Then the response code is 200
    And the response contains the following items of type StateType
      | Name    |
      | removed |
      
  Scenario: get the list of existing statetypes with limit
    When I query the collection of statetypes with a limit of 4
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse
    And the response contains 4 items of type "StateType"
    And the response contains the following items of type StateType
      | Name             |
      | new              |
      | open             |
      | closed           |
      | pending reminder |
         
  Scenario: get the list of existing statetypes with offset
    When I query the collection of statetypes with a offset 4
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse
    And the response contains 3 items of type "StateType"    
    And the response contains the following items of type StateType
      | Name             |
      | pending auto     |
      | removed          |
      | merged           |

  Scenario: get the list of existing statetypes with limit and offset
    When I query the collection of statetypes with limit 2 and offset 1
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse
    And the response contains 2 items of type "StateType"
    And the response contains the following items of type StateType
      | Name |
      | open |

  Scenario: get the list of existing statetypes with sorted
    When I query the collection of statetypes with sorted by "StateType.-Name:textual" 
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse
    And the response contains 7 items of type "StateType"
    And the response contains the following items of type StateType
      | Name             |
      | removed          |
      | pending reminder |
      | pending auto     |
      | open             |
      | new              |
      | merged           |
      | closed           |
      
  Scenario: get the list of existing statetypes with sorted, limit and offset
    When I query the collection of statetypes with sorted by "StateType.-Name:textual" limit 2 and offset 1
    Then the response code is 200
#    And the response object is StateTypeCollectionResponse
    And the response contains 2 items of type "StateType"
    And the response contains the following items of type StateType
      | Name             |
      | pending reminder |


      
      