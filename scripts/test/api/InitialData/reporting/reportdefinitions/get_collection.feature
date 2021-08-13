Feature: GET request to the /reporting/reportdefinitions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing reportdefinitions
    When I query the reportdefinitions collection
    Then the response code is 200
    And the response contains 2 items of type "ReportDefinition"
    And the response contains the following items of type ReportDefinition
      | Name                                                | Comment                                                                        |
      | Tickets Created In Date Range | Lists tickets created in a specific date range. Organization may be selected before report creation. |
      | Tickets Closed In Date Range  | Lists tickets closed in a specific date range. Organization may be selected before report creation.  |