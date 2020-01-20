 Feature: GET request to the /system/communication/notifications/:NotificationID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing notification
    Given a notification
    Then the response code is 201
    When I get this notification
    Then the response code is 200
#    And the response object is GeneralCatalogItemResponse 
    And the attribute "Notification.Comment" is "NotificationTest"
    When I delete this notification
    Then the response code is 204
    And the response has no content