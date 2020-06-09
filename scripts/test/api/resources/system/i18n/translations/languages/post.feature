Feature: POST request to the /system/i18n/translations/:PatternID/languages resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a translation language
    Given a i18n translation with
    Then the response code is 201
    When I create a translation language with
    Then the response code is 201
    Then the response object is TranslationLanguagePostPatchResponse
    When I delete this translation language
    Then the response code is 204
    And the response has no content
    When I delete this i18n translation
    Then the response code is 204
    And the response has no content