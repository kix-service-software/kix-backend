Feature: POST request to the /reporting/reports resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a report
    Given a reportdefinition
    Then the response code is 201
    When I create a report
    Then the response code is 201
    And the response object is ReportPostResponse
