 Feature: GET request to the /faq/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq articles
    When I query the collection of faq articles
    Then the response code is 200
    Then the response object is FAQArticleCollectionResponse

  Scenario: get the list of existing faq articles filtered
    Given 8 of faq articles
    When I query the collection of faq articles with filter of "General"
    Then the response code is 200
    And the response contains the following items of type FAQArticle
      | Title                                          |
      | General information on how to work with KIX 18 |
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

  Scenario: get the list of initial faq articles with limit
    Given 8 of faq articles
    When I query the collection of faq articles with limit 4
    Then the response code is 200
    And the response contains 4 items of type "FAQArticle"
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

  Scenario: get the list of initial faq articles with sorted
    Given 8 of faq articles
    When I query the collection of faq articles with sorted by "FAQArticle.-Title:textual"
    Then the response code is 200
    And the response contains 8 items of type "FAQArticle"
    And the response contains the following items of type FAQArticle
      | Title                 |
      | Title for FAQ Article |
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

  Scenario: get the list of initial faq articles with offset
    Given 8 of faq articles
    When I query the collection of faq articles with offset 6
    Then the response code is 200
    And the response contains 2 items of type "FAQArticle"
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

  Scenario: get the list of initial faq articles with limit and offset
    Given 8 of faq articles
    When I query the collection of faq articles with limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "FAQArticle"
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

  Scenario: get the list of initial faq articles with sorted, limit and offset
    Given 8 of faq articles
    When I query the collection of faq articles with sorted by "FAQArticle.-Title:textual" limit 4 and offset 1
    Then the response code is 200
    And the response contains 4 items of type "FAQArticle"
    When delete all this faq articles
    Then the response code is 204
    And the response has no content

   Scenario: get the list of existing faq articles searchlimit
     Given 66 of faq articles
     When I query the collection of faq articles 55 searchlimit
     Then the response code is 200
     And the response contains 55 items of type "FAQArticle"
     When delete all this faq articles
     Then the response code is 204
     And the response has no content

   Scenario: get the list of existing faq articles searchlimit object
     Given 66 of faq articles
     When I query the collection of faq articles 35 searchlimit object
     Then the response code is 200
     And the response contains 35 items of type "FAQArticle"
     When delete all this faq articles
     Then the response code is 204
     And the response has no content
          





