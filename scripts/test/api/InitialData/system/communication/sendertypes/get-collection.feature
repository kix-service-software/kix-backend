 Feature: GET request to the /system/communication/sendertypes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

 Scenario Outline: check is the existing sendertypes are consistent with the delivery defaults
    When I query the collection of sendertypes
    Then the response code is 200
   Then the sendertypes output is "<Name>"

   Examples:
      | Name     |
      | agent    |
      | system   |
      | external |
