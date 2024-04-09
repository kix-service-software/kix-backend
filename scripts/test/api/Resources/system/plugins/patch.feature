Feature: PATCH request to the /system/plugins/:product resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a plugin
    When I update the plugin "KIXPro"
    Then the response code is 400


