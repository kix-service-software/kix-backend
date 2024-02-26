 Feature: GET request to the /system/logs/:LogFileID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing log
    When I query the collection of logs
    Then the response code is 200
    When I get the first log
    Then the response content is
    Then the response code is 200
##    And the response object is LogFileResponse
    And the attribute "LogFile.Filename" is "TicketCounter.log"
    
  Scenario: get an existing log content
    When I query the collection of logs
    Then the response code is 200
    When I get the last log include content
    Then the response code is 200
##    And the response object is LogFileResponse
    Then the response contains the following items of type LogFile
        | the Attribute Content is available |