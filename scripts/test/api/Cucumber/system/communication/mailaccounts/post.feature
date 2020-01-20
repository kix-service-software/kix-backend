Feature: POST request to the /system/communication/mailaccounts resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a mailaccounts
    When I create a mailaccount
    Then the response code is 201
    When I delete this mailaccount
    Then the response code is 204

