Feature: GET request to the /system/cmdb/classes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: check is the existing classes are consistent with the delivery defaults
    When I query the cmdb collection of classes
    Then the response code is 200
    And the response object is ConfigItemClassCollectionResponse
    And the response contains 7 items of type "ConfigItemClass"
    And the response contains the following items of type ConfigItemClass
      | Name     |
      | Software |
      | Computer |
      | Hardware |
      | Location |
      | Building |
      | Room     |
      | Network  |
