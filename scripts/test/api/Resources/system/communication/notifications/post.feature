Feature: POST request to the /system/communication/notifications resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a notification
    When I create a notification
    Then the response code is 201
    Then the response object is NotificationPostPatchResponse
    When I delete this notification
    Then the response code is 204

