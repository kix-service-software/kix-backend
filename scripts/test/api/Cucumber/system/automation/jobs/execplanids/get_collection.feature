Feature: GET request to the /system/automation/jobs/:JobID/execPlanIds resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of execPlanIds
    Given a automation job
    Then the response code is 201
    Given a automation execplan
    Then the response code is 201
    Given a execPlanId for this automation job
    Then the response code is 201
    When I query the collection of job execPlanIds
    Then the response code is 200 
    When I delete this execPlanId
    Then the response code is 204
    And the response has no content
    When I delete this automation execplan
    Then the response code is 204     
    When I delete this automation job
    Then the response code is 204
    And the response has no content     