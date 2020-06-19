 Feature: GET request to the /system/importexport/templates/:TemplateID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing importexport template
    When I get a importexport template with ID 1
    Then the response code is 200
