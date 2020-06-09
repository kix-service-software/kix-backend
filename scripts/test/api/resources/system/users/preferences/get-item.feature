 Feature: GET request to the /system/users/:UserID/preferences/:PreferenceID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing user preference
    Given a user
    Then the response code is 201
    When added a user preference
    Then the response code is 201
    When I get this preference
    Then the response code is 200
#    And the response object is UserPreferenceResponse
    And the attribute "UserPreference.ID" is "UserListLimit"

