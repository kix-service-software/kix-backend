Feature: POST request /system/console resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a console command        
    When added a console command
    Then the response code is 200
    And the response object is ConsoleCommandPostResponse

