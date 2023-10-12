Feature: POST request to the /system/cmdb/classes/:ClassID/definitions resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a definition
    When I create a definition with classid 4
    Then the response code is 201
    Then the response object is ConfigItemClassDefinitionPostResponse
    When I delete this definition with classid 4
    Then the response code is 204



