 Feature: GET request to the /system/communication/channels resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing channels
    When I query the collection of channels
    Then the response code is 200
    And the response object is ChannelCollectionResponse

  Scenario: get the list of existing channels filtered
    When I query the collection of channels with filter of "email"
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains the following items of type Channel
      | Name  |
      | email |

  Scenario: get the list of existing channels filtered contain
    When I query the collection of channels with filter contains of "ail"
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains the following items of type Channel
      | Name  |
      | email |

  Scenario: get the list of existing channels with limit
    When I query the collection of channels with a limit of 1
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains 1 items of type Channel
    
  Scenario: get the list of existing channels with sorted
    When I query the collection of channels with sorted by "Channel.Name:textual"
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains the following items of type Channel
      | Name  |
      | email |
      | note  |      
      
  Scenario: get the list of existing channels with sorted an limit
    When I query the collection of channels sorted by "Channel.Name:textual" and with a limit of 1
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains the following items of type Channel
      | Name  |
      | email |            
      
  Scenario: get the list of existing channels with offset
    When I query the collection of channels with a offset of 1
    Then the response code is 200
    And the response object is ChannelCollectionResponse
    And the response contains the following items of type Channel
      | Name  |
      | email |            
      
      
      
      