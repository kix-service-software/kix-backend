Feature: GET request to the /system/automation/jobs/:JobID/runs/:RunID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an automation job run
    Given a automation job
    Then the response code is 201
    When I update this automation job
    Then the response code is 200
    When I query the collection of job runs
    Then the response code is 200
    When I get this automation job run
    Then the response code is 200
#    And the attribute "Job.Name" is "new job only post"
#    When I delete this automation job
#    Then the response code is 204


    
