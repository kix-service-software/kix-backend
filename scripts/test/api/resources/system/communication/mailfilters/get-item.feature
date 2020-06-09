Feature: GET request to the /system/communication/mailfilters/:MailFilterID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing mailfilter
    Given a mailfilter
    Then the response code is 201
    When I get this mailfilter
    Then the response code is 200
#    And the response object is ServiceResponse
#    And the attribute "MailFilters.Realname" is "Helpdesk"
    When I delete this mailfilter
    Then the response code is 204
    And the response has no content
    
