Feature: POST request to the /cmdb/configitems/:ConfigitemID/images resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added image to a configitem
    Given a configitem
    When added image to a configitem
    Then the response code is 201
    Then the response object is ConfigItemImagePostResponse
    When I delete this configitem
    Then the response code is 204
    And the response has no content
