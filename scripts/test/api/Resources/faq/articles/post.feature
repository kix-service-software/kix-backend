Feature: POST request to the /faq/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a faq article
    When I create a faq article
    Then the response code is 201
    Then the response object is FAQArticlePostPatchResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content

  Scenario: create a faq article with no categoryid
    When I create a faq article with no categoryid
    Then the response code is 400





