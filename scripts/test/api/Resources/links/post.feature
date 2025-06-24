Feature: POST request to the /links resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a link
    When I create a link
    Then the response code is 201
    And the response object is LinkPostResponse
    When I delete this link
    Then the response code is 204

  Scenario: create a link alredy exist
    When I create a link
    Then the response code is 201  
    When I create a link
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"
    And the error message is "Cannot create Link. A link with these parameters already exists."    
    When I delete this link
    Then the response code is 204

  Scenario: create a link with no targetobject
    When I create a link with no targetobject
    Then the response code is 400

  Scenario: create a link with no sourcekey
    When I create a link with no sourcekey
    Then the response code is 400

  Scenario: create a link with no type
    When I create a link with no type
    Then the response code is 400












