Feature: GET request to the /system/automation/jobs/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation job types
    Given a automation job
    Then the response code is 201
    When I query the collection of automation job types
    Then the response code is 200
#    And the response object is JobTypeCollectionsResponse
    When I delete this automation job
    Then the response code is 204
    And the response has no content     