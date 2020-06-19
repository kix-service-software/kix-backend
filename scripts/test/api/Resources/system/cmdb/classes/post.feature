Feature: POST request to the /system/cmdb/classes resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: create a configitem class
    When I create a configitem class
    Then the response code is 201
    Then the response object is ConfigItemClassPostPatchResponse
    When I delete this configitem class
    Then the response code is 204

