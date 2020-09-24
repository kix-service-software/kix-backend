 Feature: GET request to the /faq/articles/:faqArticleId/votes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq article votes
    When I query the collection of faq articles ID 1 votes
    Then the response code is 200
Then the response content is
    Then the response contains 1 items of type "FAQVote"
    And the response contains the following items of type FAQVote
      | Interface | ArticleID | Rating |
      | 1         | 1         | 5      |


