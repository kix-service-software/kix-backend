 Feature: GET request to the /system/communication/channels resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: check is the existing channels are consistent with the delivery defaults
    When I query the collection of channels
    Then the response code is 200
    And the response object is ChannelCollectionResponse
#Then the response content is
    Then the response contains 2 items of type "Channel"
    And the response contains the following items of type Channel
      | Name           | ValidID |
      | note           | 1       |
      | email          | 1       |

         
