Feature: GET request to the /reporting/reports/:ReportID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing reportdefinition report
    Given a reportdefinition
    Given a report
    When I get this report
    Then the response code is 200
    When I delete this reportdefinition
    Then the response code is 204
    And the response has no content



    
