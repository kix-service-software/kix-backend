 Feature: GET request to the /system/communication/sendertypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing sendertypes
    When I query the collection of sendertypes
    Then the response code is 200
    And the response object is SenderTypeCollectionResponse

  Scenario: get the list of existing sendertypes filtered
    When I query the collection of sendertypes with filter of system
    Then the response code is 200
    And the response contains the following items of type SenderType
      | Name   |
      | system |

  Scenario: get the list of existing sendertypes filtered contain
    When I query the collection of sendertypes with filter contains of "ex"
    Then the response code is 200
    And the response contains the following items of type SenderType
      | Name     |
      | external |

  Scenario: get the list of existing sendertypes with limit
    When I query the collection of sendertypes with a limit of 1
    Then the response code is 200
    And the response object is SenderTypeCollectionResponse
    And the response contains 1 items of type SenderType
    
      
      