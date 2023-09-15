Feature: POST request to the /faq/articles/:FAQArticleID/attachments resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a faq article attachment
    Given a faq article
    When I create a faq article attachment
    Then the response code is 201
    Then the response object is FAQAttachmentPostPatchResponse
    When I delete this faq article
    Then the response code is 204
    And the response has no content
