Feature: GET request to the /system/automation/execplans/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of automation execplan types
    Given a automation execplan
    Then the response code is 201
    When I query the collection of automation execplan types
    Then the response code is 200
    And the response object is ExecPlanTypeCollectionResponse
    When I delete this automation execplan
    Then the response code is 204
    And the response has no content   