Feature: POST request to the /auth resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__

  Scenario: authenticate as a valid user
    Given I am an agent user with login "admin" and password "Passw0rd"
    When I login
    Then the response code is 201
    And the response object is AuthResponse
    And the response contains a valid token

