Feature: POST request /contacts resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: added a contact
    Given a organisation
    When added a contact
    Then the response code is 201
    Then the response object is ContactPostPatchResponse
    When I delete this contact
    Then the response code is 204
    When I delete this organisation
    Then the response code is 204
    And the response has no content

  Scenario: I create a contact with a email that already exists
    Given a organisation
    When added a contact
    When added a contact with a email that already exists
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"
    And the error message is "Cannot create contact. Another contact with email address "mamu@example.org" already exists."
    When I delete this contact
    Then the response code is 204
    When I delete this organisation
    Then the response code is 204
    And the response has no content


