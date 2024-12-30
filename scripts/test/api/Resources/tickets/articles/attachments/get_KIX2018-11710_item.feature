Feature: GET request to the /tickets/:TicketID/articles/:ArticleID/attachments resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing article with article df
    Given a ticket
    Then the response code is 201
    When I create a article with inline pic
    Then the response code is 201
    When I get the article
    Then the response code is 200
    When I get the inline attachment item
    Then the response code is 200
#    Then the response content is
    And the response contains the following items of type Attachment
      | ContentType                    | Disposition | Filesize    | FilesizeRaw | Filename   |
      | text/html; charset=\"utf-8\"   | inline      | 72 Bytes    | 72          | file-2     |
      | image/png; name=\"grafik.png\" | inline      | 20.5 KBytes | 20951       | grafik.png |
    When I delete this ticket
    Then the response code is 204
    And the response has no content



    
