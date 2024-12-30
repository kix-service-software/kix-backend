Feature: GET request to the /tickets/:TicketID/articles/:ArticleID/attachments/zip resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing attachments zip
    Given a ticket
    Given a article
    Given a article attachment
    When I query the attachments zip collection
    Then the response code is 200
#    Then the response object is TicketArticleAttachmentZipResponse
#    Then the response content is
    And the response contains the following zip Attachment
      | ContentType     | Filesize   | FilesizeRaw |
      | application/zip | 6.7 KBytes | 6815        |
    When I delete this ticket
    Then the response code is 204
    And the response has no content 


