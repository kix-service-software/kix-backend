 Feature: GET request to the /system/config/definitions/::Option resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing config definition
    When I get the config definitions with Option "ProductName"
    Then the response code is 200

