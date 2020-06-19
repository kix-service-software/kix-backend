Feature: GET request to the /system/dynamicfields resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing dynamicfields
    Given a dynamicfield
    Then the response code is 200
    When I query the collection of dynamicfields
    Then the response code is 200
    When I delete this dynamicfield
    Then the response code is 204
    And the response has no content

