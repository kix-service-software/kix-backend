Feature: GET request to the /system/i18n/translations/:TranslationID/languages resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing languages
    When I query the collection of languages with PatternID 1
    Then the response code is 200
#    And the response object is TranslationLanguageCollectionResponse
  

