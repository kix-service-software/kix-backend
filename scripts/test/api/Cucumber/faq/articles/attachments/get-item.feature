 Feature: GET request to the /faq/articles/:FAQArticleID/attachments/:FAQAttachmentID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing faq article attachment
    Given a faq article
    Then the response code is 201
    Given a faq article attachment
    Then the response code is 201
    When I get this faq article attachment
    Then the response code is 200
    And the attribute "Attachment.Filename" is "Queue.xml"
    When I delete this faq article
    Then the response code is 204
    And the response has no content