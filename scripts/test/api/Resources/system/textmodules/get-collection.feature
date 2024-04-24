 Feature: GET request to the /system/textmodules resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of textmodules
    When I query the collection of textmodules with filter of Anrede
    Then the response code is 200
#    And the response object is TextModuleCollectionResponse

  Scenario: get the list of textmodules with filter
    When I query the collection of textmodules with filter of Anrede
    Then the response code is 200
    And the response contains the following items of type TextModule
      | Name   | Language |
      | Anrede | de       |
      
  Scenario: get the list of textmodules with limit
    When I query the collection of textmodules with a limit of 1
    Then the response code is 200
    And the response contains 1 items of type "TextModule"