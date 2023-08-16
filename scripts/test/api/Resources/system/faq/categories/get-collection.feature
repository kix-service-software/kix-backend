 Feature: GET request to the /system/faq/categories resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing faq categories
    When I query the collection of faq categories
    Then the response code is 200

   Scenario: get the list of existing faq categories
     When I query the collection of faq categories
     Then the response code is 200
     And the response contains 1 items of type "FAQCategory"
     And the response contains the following items of type FAQCategory
       | Name |
       | Misc |

  Scenario: get the list of existing faq categories with filter
    Given a faq category
    When I query the collection of faq categories with filter of "KIX18-Funktionen given"
    Then the response code is 200
    And the response contains the following items of type FAQCategory
      | Fullname               |
      | KIX18-Funktionen given |
    When I delete this faq category
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing faq categories with limit
    Given a faq category
    When I query the collection of faq categories with a limit of 1
    Then the response code is 200 
    And the response contains 1 items of type "FAQCategory"
    And the response contains the following items of type FAQCategory
      | Name |
      | Misc |
    When I delete this faq category
    Then the response code is 204
    And the response has no content
