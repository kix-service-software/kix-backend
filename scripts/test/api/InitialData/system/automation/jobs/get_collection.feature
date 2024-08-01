Feature: GET request to the /system/automation/jobs resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation jobs
    When I query the collection of automation jobs
    Then the response code is 200
    Then the response contains 4 items of type "Job"
    And the response contains the following items of type Job
      | Name                                         | Comment                                                                                                    | Type      | ValidID |
      | Customer Response - reopen from pending      | Reopens ticket from pending by customer response.                                                          | Ticket    | 1       |
      | KIX Field Agent - Mobile Processing Rejected | This job resets owner and lock state of a ticket, when its mobile processing state is set to \"rejected\". | Ticket    | 1       |
      | Owner Out Of Office - unlock ticket          | Unlock ticket when owner is out of office.                                                                 | Ticket    | 1       |
      | Periodic Reports                             | Executes all reports that should be created periodically.                                                  | Reporting | 1       |
