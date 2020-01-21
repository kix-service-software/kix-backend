 Feature: GET request to the /system/ticket/locks/:LockID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing ticket lock
    When I get the ticket lock with lockId 2
    Then the response code is 200
    And the attribute "Lock.Name" is "lock"

