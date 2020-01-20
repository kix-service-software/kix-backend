Feature: POST request to the /system/i18n/translations resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a translation
    When I create a i18n translation with
    Then the response code is 201
    Then the response object is TranslationPatternPostPatchResponse
    When I delete this i18n translation
    Then the response code is 204
    Then the response has no content
    
