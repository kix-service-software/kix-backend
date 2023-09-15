Feature: GET request to the /system/automation/execplans resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation execplans
    Given a automation execplan
    Then the response code is 201
    When I query the collection of automation execplans
    Then the response code is 200
#    And the response object is ExecPlanCollectionResponse
    When I delete this automation execplan
    Then the response code is 204
    And the response has no content   
