Feature: POST request to the /system/oauth2/profiles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a oauth2-profile
    When I create a oauth2-profile
    Then the response code is 201
    When I delete this oauth2-profile
    Then the response code is 204
    Then the response has no content
    
