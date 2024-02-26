Feature: GET request to the /system/automation/macros/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation macro types
    When I query the collection of automation macro types
    Then the response code is 200
    And the response contains 4 items of type "MacroType"
    And the response contains the following items of type MacroType
      | Name            | DisplayName     |
      | Contact         | Contact         |
      | Reporting       | Reporting       |
      | Synchronisation | Synchronisation |
      | Ticket          | Ticket          |
