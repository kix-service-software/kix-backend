 Feature: GET request to the /system/console resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing console command
    When I query the collection of console
    Then the response code is 200
    And the response object is ConsoleCommandCollectionResponse

  Scenario: get the list of existing console command filter
    When I query the collection of console with filter command "Maint::Cache::Delete"
    Then the response code is 200
    And the response object is ConsoleCommandCollectionResponse
    And the response contains the following items of type ConsoleCommand
      | Command              |
      | Maint::Cache::Delete |