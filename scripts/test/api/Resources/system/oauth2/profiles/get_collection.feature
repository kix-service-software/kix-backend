Feature: GET request to the  /system/oauth2/profiles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing oauth2-profiles
    Given a oauth2-profile
    When I query the collection of oauth2-profiles
    Then the response code is 200


