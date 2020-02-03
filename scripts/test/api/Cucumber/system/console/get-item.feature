 Feature: GET request to the /system/console/{consoleCommand} resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing console command
    When I get this console command "Maint::Cache::Delete"
    Then the response code is 200
    And the response object is ConsoleCommandResponse