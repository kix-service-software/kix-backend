Feature: GET request to the /reporting/reportdefinitions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario Outline: get the list of existing reportdefinitions
    When I query the reportdefinitions collection
    Then the response code is 200
    Then the reportdefinitions output is "<Name>"
    
     Examples:   
      | Name                                             |
      | Tickets Created In Date Range                    |
      | Tickets Closed In Date Range                     |
      | Number of tickets created within the last 7 days |
      | Number of open tickets by priority               |
      | Number of open tickets by state                  |
      | Number of open tickets in teams by priority      |
      | Number of open tickets by team                   |
      | Number of tickets closed within the last 7 days  |


  Scenario: get the list of existing reportdefinitions
    When I query the reportdefinitions collection
    Then the response code is 200
    And the response contains 8 items of type "ReportDefinition"
    And the response contains the following items of type ReportDefinition
      | Name                                             | Comment                                                                                              |
      | Tickets Created In Date Range                    | Lists tickets created in a specific date range. Organization may be selected before report creation. |
      | Tickets Closed In Date Range                     | Lists tickets closed in a specific date range. Organization may be selected before report creation.  |
      | Number of tickets created within the last 7 days | Lists tickets created within the last 7 days.                                                        |
      | Number of open tickets by priority               | Lists open tickets by priority.                                                                      |
      | Number of open tickets by state                  | Lists open tickets by state.                                                                         |
      | Number of open tickets in teams by priority      | Lists open tickets in teams by priority.                                                             |
      | Number of open tickets by team                   | Lists open tickets by team.                                                                          |
      | Number of tickets closed within the last 7 days  | Lists closed tickets within the last 7 days.                                                         |

















