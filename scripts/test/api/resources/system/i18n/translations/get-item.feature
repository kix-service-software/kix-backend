Feature: GET request to the /system/i18n/translations/:PatternID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing translation
    Given a i18n translation with
    Then the response code is 201
    When I get the i18n translation
    Then the response code is 200
#    And the response object is TranslationPatternResponse
#    And the attribute "TranslationPattern.ChangeBy" is 1
    When I delete this i18n translation
    Then the response code is 204
    And the response has no content    
