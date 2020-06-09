Feature: DELETE request to the /system/cmdb/classes/:ClassID/definitions/:DefinitionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this definition
    Given a definition with classid 4
    Then the response code is 201
    When I delete this definition with classid 4
    Then the response code is 204
    And the response has no content
