 Feature: GET request to the /system/communication/mailaccounts resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing mailaccounts
    Given a mailaccount
    When I query the collection of mailaccounts 
    Then the response code is 200
#    Then the response object is MailAccountCollectionResponse
    When I delete this mailaccount
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing mailaccounts
    Given 4 of mailaccount
    When I query the collection of mailaccounts with filter of filter.test
    Then the response code is 200
    And the response contains the following items of type MailAccount
      | Login       |
      | filter.test |
    When I delete this mailaccount
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing mailaccounts with limit
    Given 4 of mailaccount
    When I query the collection of mailaccounts with a limit of 3
    Then the response code is 200
    And the response contains 3 items of type "MailAccount"
    When I delete this mailaccount
    Then the response code is 204
    And the response has no content
    
    