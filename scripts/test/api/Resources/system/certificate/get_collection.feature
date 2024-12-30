Feature: GET request to the /system/certificates resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing certificates
    When I query collection of certificates
    Then the response code is 200
#    Then the response content is


