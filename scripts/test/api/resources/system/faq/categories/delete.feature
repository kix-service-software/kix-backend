Feature: DELETE request to the /system/faq/categories/:FAQCategoryID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this faq category
    Given a faq category
    Then the response code is 201
    When I delete this faq category
    Then the response code is 204
    And the response has no content

