 Feature: GET request to the /faq/articles/:FAQArticleID/history resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing faq article history
    Given a faq article
    When I query the collection of faq article history
    Then the response code is 200
    Then the response object is FAQHistoryCollectionResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content

