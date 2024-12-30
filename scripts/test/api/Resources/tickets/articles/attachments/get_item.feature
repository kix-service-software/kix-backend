Feature: GET request to the /tickets/:TicketID/articles/:ArticleID/attachments/:AttachmentID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing attachment
    Given a ticket
    Given a article
    Given a article attachment
    When I get the attachment item
    Then the response code is 200
    And the response contains the following items of type Attachment
      | ContentType                  | Disposition | Filesize   | FilesizeRaw | Filename                                                                              |
      | text/html; charset=\"utf-8\" | inline      | 72 Bytes   | 72          | file-2                                                                                |
      | application/pdf              | attachment  | 7.1 KBytes | 7255        | ein-langer-dateiname-fuer-eine-pdf-datei-ein-langer-dateiname-fuer-eine-pdf-datei.pdf |
    When I delete this ticket
    Then the response code is 204
    And the response has no content 




    
