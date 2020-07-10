Feature: GET request to the /system/i18n/translations/:TranslationID/languages/:Language resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get a specific language
    Given a i18n translation with
    Given a translation language with
    When I get this translation language
    Then the response code is 200
    When I delete this translation language
    Then the response code is 204
    And the response has no content
    When I delete this i18n translation
    Then the response code is 204
    And the response has no content

