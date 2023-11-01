Feature: PATCH request to the /reporting/reportdefinitions/:ReportDefinitionId resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a reportdefinition
    Given a reportdefinition
    When I update this reportdefinition
    Then the response code is 200
    And the response object is ReportDefinitionPostPatchResponse
    When I delete this reportdefinition
    Then the response code is 204


