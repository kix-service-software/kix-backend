 Feature: GET request to the /faq/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq articles
    When I query the collection of faq articles
    Then the response code is 200

  Scenario: get the list of existing faq articles filtered
    When I query the collection of faq articles with filter of General
    Then the response code is 200
    And the response contains the following items of type FAQArticle
      | Title                                          |
      | General information on how to work with KIX 18 |

  Scenario: get the list of initial faq articles with limit
    When I query the collection of faq articles with limit 4
    Then the response code is 200
    And the response contains 4 items of type FAQArticle
    
  Scenario: get the list of initial faq articles with sorted 
    When I query the collection of faq articles with sorted by "FAQArticle.-Title:textual"
    Then the response code is 200
    And the response contains 8 items of type FAQArticle
    And the response contains the following items of type FAQArticle
      | Title                    |
      | Wie suche ich in KIX 18? |    

  Scenario: get the list of initial faq articles with offset
    When I query the collection of faq articles with offset 4
    Then the response code is 200
    And the response contains 8 items of type FAQArticle
    
  Scenario: get the list of initial faq articles with limit and offset
    When I query the collection of faq articles with limit 2 and offset 4
    Then the response code is 200
    And the response contains 2 items of type FAQArticle
  
  Scenario: get the list of initial faq articles with sorted, limit and offset
    When I query the collection of faq articles with sorted by "Address.-EmailAddress:textual" limit 2 and offset 4
    Then the response code is 200
    And the response contains 2 items of type FAQArticle





          