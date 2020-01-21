Feature: PATCH request to the /system/services/:ServiceID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a service
    Given a service with
    Then the response code is 201
    When I update this service
    Then the response code is 200
    And the response object is ServicePostPatchResponse
    When I delete this service
    Then the response code is 204

