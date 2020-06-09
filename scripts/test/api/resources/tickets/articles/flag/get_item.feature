Feature: the /tickets/:TicketID/articles/:ArticleID/attachments/:AttachmentID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing article flag
    Given a ticket
    Then the response code is 201
    Given a article
    Then the response code is 201
    When I create a article flag
      | Name                      | Value |
      | Flag__GET_RANDOM_STRING__ | on    |
      Then the response code is 201
    When I get the article flag
    Then the response code is 200
    And the attribute "ArticleFlag.Value" is "on"
    When I delete this ticket
    Then the response code is 204
    And the response has no content





    
