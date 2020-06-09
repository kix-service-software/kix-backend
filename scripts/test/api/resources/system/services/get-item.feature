Feature: GET request to the /system/services/:ServiceID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing service
    Given a service with
    Then the response code is 201
    When I get this service
    Then the response code is 200
    And the response object is ServiceResponse
    And the attribute "Service.Comment" is "ServicesComment"
    When I delete this service
    Then the response code is 204
    And the response has no content
    
