Feature: POST request to the /faq/articles/:FAQArticleID/votes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a faq article votes
    Given a faq article
    When I create a faq article votes
    Then the response code is 201
    Then the response object is FAQVotePostPatchResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content
