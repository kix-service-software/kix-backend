 Feature: GET request to the /system/faq/categories resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: check is the existing faq categories are consistent with the delivery defaults
    When I query the collection of faq categories
    Then the response code is 200
    Then the response contains 2 items of type "FAQCategory"
    And the response contains the following items of type FAQCategory
      | Name |
      | Misc |
      | KIX  |