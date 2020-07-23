Feature: GET request to the /system/ticket/states/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

 Scenario: check is the existing statetypes are consistent with the delivery defaults
    When I query the collection of statetypes
    Then the response code is 200
    And the response object is StateTypeCollectionResponse
    And the response contains 7 items of type "StateType"
    And the response contains the following items of type StateType
      | Name             |
      | new              |
      | open             |
      | closed           |
      | pending reminder |
      | pending auto     |
      | removed          |
      | merged           |
 