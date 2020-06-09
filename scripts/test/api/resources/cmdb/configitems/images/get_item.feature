Feature: GET request to the /cmdb/configitems/images resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing image
    Given a configitem
    Then the response code is 201
    When added image to a configitem
    Then the response code is 201 
    When I get the configitem image from configitem
    Then the response code is 200
#    And the response object is ConfigItemImageResponse
    And the attribute "Image.Comment" is "this is a test"
    When I delete this configitem
    Then the response code is 204
    And the response has no content



    
