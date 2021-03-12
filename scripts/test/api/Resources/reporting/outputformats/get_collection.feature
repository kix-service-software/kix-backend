Feature: GET request to the /reporting/outputformats resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing outputformats
    When I query the outputformats collection
    Then the response code is 200
