 Feature: GET request to the /system/valid resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario Outline: check is the existing valid are consistent with the delivery defaults
    When I query the collection of valid
    Then the response code is 200
    Then the valid output is "<Name>"

    Examples:
      | Name                 |
      | valid                |
      | invalid              |
      | invalid-temporarily  |
