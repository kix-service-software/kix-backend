 Feature: GET request to the /system/valid/:ValidID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing valid
    When I get the valid with ID 3
    Then the response code is 200
#    And the response object is ValidResponse
    And the attribute "Valid.Name" is "invalid-temporarily"

