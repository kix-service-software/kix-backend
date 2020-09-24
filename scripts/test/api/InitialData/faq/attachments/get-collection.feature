 Feature: GET request to the /faq/articles/:faqArticleId/attachments resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq article attachments
    When I query the collection of faq articles ID 1 attachments
    Then the response code is 200
    Then the response contains 1 items of type "Attachment"
    And the response contains the following items of type Attachment
      | Filename                     | Contenttype | FileSize     | Disposition | FilesizeRaw |
      | pasted-1563537680-407593.png | img/png     | 106.8 KBytes | inline      | 109337      |


