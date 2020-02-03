Feature: POST request to the /system/users/:UserID/preferences resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a user preference
    Given a user
    Then the response code is 201
     When added a user preference
     Then the response code is 201
     Then the response object is UserPreferencePostPatchResponse
     When I delete this user preference
     Then the response code is 204

