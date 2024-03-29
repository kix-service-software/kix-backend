Feature: POST request /system/config/definitions resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: added a config definitions
    When added a config definitions
    Then the response code is 201
    When I delete this config definitions "test"
    Then the response code is 204
    And the response has no content

