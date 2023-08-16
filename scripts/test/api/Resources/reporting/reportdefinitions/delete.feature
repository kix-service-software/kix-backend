Feature: DELETE request to the /reporting/reportdefinitions/:ReportDefinitionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this reportdefinition
    Given a reportdefinition
    Then the response code is 201
    Then the response content is
    When I delete this reportdefinition
    Then the response code is 204
    And the response has no content
