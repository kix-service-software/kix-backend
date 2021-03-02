Feature: GET request to the /system/automation/jobs resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation jobs
    When I query the collection of automation jobs
    Then the response code is 200
    Then the response contains 7 items of type "Job"
    And the response contains the following items of type Job
