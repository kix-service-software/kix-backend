Feature: DELETE request to the /reporting/reports/:ReportID/results/:ReportResultID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this report result
    Given a reportdefinition
    Given a report
    When I get this report result
    Then the response code is 200
    When I delete this report result
    Then the response code is 204
    And the response has no content
    When I delete this reportdefinition
    Then the response code is 204
    And the response has no content
