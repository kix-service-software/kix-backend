Feature: PATCH request to the /system/communication/notifications/:NotificationID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a notification
    Given a notification
    When I update this notification
    Then the response code is 200
    Then the response object is NotificationPostPatchResponse
    When I delete this notification
    Then the response code is 204
    And the response has no content

