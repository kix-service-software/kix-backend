Feature: PATCH request to the /system/cmdb/classes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a class
    Given a configitem class
    Then the response code is 201
    When I update this configitem class
    Then the response code is 200
    And the response object is ConfigItemClassPatchRequest
    When I delete this configitem class
    Then the response code is 204


