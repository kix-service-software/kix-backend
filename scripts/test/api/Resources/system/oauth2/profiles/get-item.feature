Feature: GET request to the /system/oauth2/profiles/:ProfileID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing oauth2-profile
    Given a oauth2-profile
    When I get the oauth2-profile
    Then the response code is 200
    When I delete this oauth2-profile
    Then the response code is 204
    And the response has no content    
