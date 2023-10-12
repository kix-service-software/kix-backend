Feature: POST request to the /cmdb/configitems resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: create a configitem
    When I create a configitem
    Then the response code is 201
    Then the response object is ConfigItemPostPatchResponse
    When I delete this configitem
    Then the response code is 204
    And the response has no content

  Scenario: create a configitem
    When I create a configitem with not existing class id
    Then the response code is 400
    And the response object is Error
    And the error code is "BadRequest"
#    And the error message is "Parameter ConfigItem::ClassID is not one of '10,4,5,6,7,8,9'!"

  Scenario: create a configitem
    When I create a configitem with no class id
    Then the response code is 400
    And the response object is Error
    And the error code is "BadRequest"
#    And the error message is "Parameter ConfigItem::ClassID is not one of '10,4,5,6,7,8,9'!"

  Scenario: create a configitem
    When I create a configitem with no incistate id
    Then the response code is 400
    And the response object is Error
    And the error code is "BadRequest"
    And the error message is "Required parameter ConfigItem::Version::InciStateID is missing or undefined!"

