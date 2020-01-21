Feature: GET request to the /system/automation/jobs resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an automation job
    Given a automation job
    Then the response code is 201
    When I get this automation job
    Then the response code is 200
    And the attribute "Job.Name" is "new job only"
    When I delete this automation job
    Then the response code is 204


    
