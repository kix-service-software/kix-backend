Feature: PATCH request to the /faq/articles/:FAQArticleID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a faq article
    Given a faq article
    When I update this faq article
    Then the response code is 200
#    Then the response object is FAQArticlePostPatchResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content

