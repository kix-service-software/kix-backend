 Feature: GET request to the /faq/articles/:FAQArticleID/votes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing faq article votes
    Given a faq article
    Given a faq article votes
    When I query the collection of faq article votes
    Then the response code is 200
    Then the response object is FAQVoteCollectionResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content

