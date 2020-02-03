 Feature: GET request to the /system/textmodules/categories resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of textmodules categories
    When I query the collection of textmodules categories
    Then the response code is 200




