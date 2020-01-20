Feature: GET request to the /tickets/:TicketID/articles/:ArticleID/attachments/:AttachmentID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing attachment
    Given a ticket
    Then the response code is 201
    Given a article
    Then the response code is 201
    Given a article attachment
    Then the response code is 201
    When I get the attachment item
    Then the response code is 200
    And the attribute "Attachment.Filename" is "ein-langer-dateiname-fuer-eine-pdf-datei-ein-langer-dateiname-fuer-eine-pdf-datei.pdf" 
    When I delete this ticket
    Then the response code is 204
    And the response has no content 




    
