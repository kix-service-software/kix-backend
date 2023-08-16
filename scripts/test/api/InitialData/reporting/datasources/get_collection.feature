Feature: GET request to the /reporting/datasources resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as Agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing datasources
    When I query the datasources collection
    Then the response code is 200
    And the response contains 1 items of type "DataSource"
    And the response contains the following items of type DataSource
      | Name       | DisplayName | Description                                               |
      | GenericSQL | Generic SQL | Allows to retrieve report data based on an SQL statement. |



















