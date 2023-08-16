Feature: GET request to the /cmdb/configitems/:ConfigItemID/versions/:VersionID/attachments/:AttachmentID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing attachment
    Given a configitem with attachment
    When I get this configitem
    When I get the attachment with attachmentid 1
    Then the response code is 200
    And the attribute "Attachment.Filename" is "Test2.pdf"
    And the response object is ConfigItemAttachmentResponse



    
