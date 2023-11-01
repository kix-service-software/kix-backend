Feature: PATCH request to the /system/communication/mailaccounts/:MailAccountID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a mailaccount
    Given a mailaccount
    When I update this mailaccount
    Then the response code is 200
#    Then the response object is MailAccountPostPatchResponse
    When I delete this mailaccount
    Then the response code is 204
    And the response has no content

