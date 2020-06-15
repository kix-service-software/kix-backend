Feature: DELETE request to the /cmdb/configitems/:ConfigitemID/images/:ImageID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: delete this image
    Given a configitem
    When added image to a configitem
    When I delete this image on configitemid
    Then the response code is 204
    And the response has no content
