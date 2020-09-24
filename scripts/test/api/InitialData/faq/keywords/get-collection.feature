 Feature: GET request to the /faq/articles/:faqArticleId/keywords resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq article keywords
    When I query the collection of faq articles keywords
    Then the response code is 200
Then the response content is
    Then the response contains 3 items of type "FAQKeyword"
    And the response contains the following items of type FAQKeyword
      | Keyword |
      | sprache |


