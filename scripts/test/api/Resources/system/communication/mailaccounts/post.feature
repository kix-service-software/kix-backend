Feature: POST request to the /system/communication/mailaccounts resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a mailaccounts
    When I create a mailaccount
    Then the response code is 201
    Then the response object is MailAccountPostPatchResponse
    When I delete this mailaccount
    Then the response code is 204

  Scenario: create a mailaccounts failed type
    When I create a mailaccount failed type
    Then the response code is 400
    And the response object is Error
    And the error code is "BadRequest"
    And the error message is "Parameter MailAccount::Type is not one of 'IMAP,IMAPS,IMAPS_OAuth2,IMAPTLS,IMAPTLS_OAuth2,POP3,POP3S,POP3TLS,POP3TLS_OAuth2'!"