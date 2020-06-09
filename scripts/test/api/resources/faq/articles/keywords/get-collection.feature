 Feature: GET request to the /faq/articles/keywords resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing faq article keywords 
    Given a faq article
    Then the response code is 201
    When I query the collection of faq article keywords
    Then the response code is 200
    And the response object is FAQKeywordCollectionResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content

