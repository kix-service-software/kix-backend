 Feature: GET request to the /faq/articles/:faqArticleId/history resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq article history
    When I query the collection of faq articles ID 1 history
    Then the response code is 200
    Then the response contains 2 items of type "FAQHistory"
    And the response contains the following items of type FAQHistory
      | Name    |
      | Created |
      | Created |

