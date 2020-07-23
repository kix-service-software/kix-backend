Feature: GET request to the /system/dynamicfields/objecttypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get a collection of existing dynamicfield objecttypes
    When I get a collection of dynamicfield objecttypes
    Then the response code is 200

  Scenario: get a collection of existing dynamicfield objecttypes filtered
    When I get a collection of dynamicfield objecttypes with filter "FAQ"
    Then the response code is 200
    And the response contains the following items of type DynamicFieldObject
      | Name | DisplayName |
      | FAQ  | FAQ         |


    
