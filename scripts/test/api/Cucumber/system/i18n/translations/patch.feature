Feature: PATCH request to the /system/i18n/translations/:TranslationID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a i18n translation
    Given a i18n translation with
    Then the response code is 201 
    When I update this translation with
    Then the response code is 200
    And the response object is TranslationPatternPostPatchResponse
    When I delete this i18n translation
    Then the response code is 204
