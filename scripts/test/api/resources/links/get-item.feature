 Feature: GET request to the /links/:LinkID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing mailaccount
    Given a link
    Then the response code is 201
    When I get this link
    Then the response code is 200 
    And the attribute "Link.Type" is "Normal"
    And the response object is LinkResponse
    When I delete this link
    Then the response code is 204
    And the response has no content