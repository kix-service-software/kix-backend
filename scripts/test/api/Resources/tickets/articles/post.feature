Feature: POST request to the /tickets/:TicketID/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a article
    Given a ticket
    When I create a article
    Then the response code is 201
    Then the response object is TicketArticlePostPatchResponse
    When I delete this article
    Then the response code is 204
    When I delete this ticket
    Then the response code is 204
    And the response has no content

  Scenario: create a article with fail mimetype
    Given a ticket
    When I create a article with fail mimetype
    Then the response code is 400
    And the error code is "Validator.Failed"
    And the error message is "Validation of attribute ContentType (html/text; charset=utf8) failed! Invalid MimeType!"
    When I delete this ticket
    Then the response code is 204
    And the response has no content

  Scenario: create a article with fail mimetype (write error)
    Given a ticket
    When I create a article with fail mimetype 2
    Then the response code is 400
    And the error code is "Validator.Failed"
    And the error message is "Validation of attribute ContentType (text/pain; charset=utf8) failed! Invalid MimeType!"
    When I delete this ticket
    Then the response code is 204
    And the response has no content

