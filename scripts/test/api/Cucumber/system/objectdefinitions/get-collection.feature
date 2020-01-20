 Feature: GET request to the /system/objectdefinitions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing objectdefinitions
    When I query the collection of objectdefinitions
    Then the response code is 200

