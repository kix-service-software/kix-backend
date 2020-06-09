 Feature: GET request to the /faq/articles/:FAQArticleID/votes/:FAQVoteID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing faq article votes
    Given a faq article
    Then the response code is 201
    Given a faq article votes
    Then the response code is 201
    When I get this faq article votes
    Then the response code is 200
    And the attribute "FAQVote.CreatedBy" is "Max Mustermann"
    When I delete this faq article
    Then the response code is 204
    And the response has no content