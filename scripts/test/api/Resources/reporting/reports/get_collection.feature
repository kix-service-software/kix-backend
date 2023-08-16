Feature: GET request to the /reporting/reports resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing reportdefinitions reports
    Given a reportdefinition
    Then the response code is 201
    Given a report
    Then the response code is 201
    When I query the reports collection
    Then the response code is 200
#    And the response object is ReportDefinitionCollectionResponse
    When I delete this reportdefinition
    Then the response code is 204