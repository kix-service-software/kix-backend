Feature: the /tickets/:TicketID/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing articles
    Given a ticket
    Then the response code is 201
    Given a article
    Then the response code is 201
    When I query the articles collection
    Then the response code is 200
    When I delete this ticket
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing articles with limit
    Given a ticket
    Then the response code is 201
    Given 8 of articles
    When I query the articles collection with limit 4
    Then the response code is 200
    And the response contains 4 items of type Article
    When I delete this ticket
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing articles with offset
    Given a ticket
    Then the response code is 201
    Given 8 of articles
    When I query the articles collection with offset 4
    Then the response code is 200
    And the response contains 4 items of type Article
    When I delete this ticket
    Then the response code is 204
    And the response has no content 
    
  Scenario: get the list of existing articles with limit and offset
    Given a ticket
    Then the response code is 201
    Given 8 of articles
    When I query the articles collection with limit 2 and offset 4
    Then the response code is 200
    And the response contains 2 items of type Article
    When I delete this ticket
    Then the response code is 204
    And the response has no content     
       