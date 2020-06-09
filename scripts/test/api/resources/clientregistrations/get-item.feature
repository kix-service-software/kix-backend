 Feature: GET request to the /clientregistration/:ClientID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing clientregistration
    Given a clientregistration
    Then the response code is 201
    When I get this clientregistration
    Then the response code is 200
    And the response object is ClientRegistrationResponse
    And the attribute "ClientRegistration.NotificationURL" is "http://kix-frontend.example.org/notifications"
    When I delete this clientregistration
    Then the response code is 204
    And the response has no content
