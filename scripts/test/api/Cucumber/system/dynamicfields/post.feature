Feature: POST request to the /system/dynamicfields resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a dynamicfield
    When I create a dynamicfield
    Then the response code is 200
    When I delete this dynamicfield
    Then the response code is 204

