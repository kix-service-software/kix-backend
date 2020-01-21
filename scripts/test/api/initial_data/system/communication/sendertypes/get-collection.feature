 Feature: GET request to the /system/communication/sendertypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

 Scenario: check is the existing sendertypes are consistent with the delivery defaults
    When I query the collection of sendertypes
    Then the response code is 200
#Then the response content is
    And the response object is SenderTypeCollectionResponse
    And the response contains 3 items of type "SenderType"
    And the response contains the following items of type SenderType
      | Name     |
      | agent    |
      | system   |
      | external |
