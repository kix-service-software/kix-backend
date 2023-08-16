Feature: PATCH request to the /tickets/:TicketID/articles/:ArticleID/flags/:FlagName resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a article flag
    Given a ticket
    Given a article
    When I create a article flag
    Then the response code is 201
    When I update this article flag
    Then the response code is 200
    Then the response object is TicketArticleFlagPostPatchResponse
    When I delete this ticket
    Then the response code is 204
    And the response has no content




