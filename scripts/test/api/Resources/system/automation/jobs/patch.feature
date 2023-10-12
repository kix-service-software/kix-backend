Feature: PATCH request to the /system/automation/jobs resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a automation job
    Given a automation job
    Then the response code is 201
    When I update this automation job
    Then the response code is 200
    And the response object is JobPostPatchResponse
#    When I delete this automation job
#    Then the response code is 204


