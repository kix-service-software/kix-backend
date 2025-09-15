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

  Scenario: authenticate with no valid password
    Given I am an agent user with login "admin" and password "PasswOrd"
    When I login
    Then the response code is 401
    And the response object is Error
    And the error code is "SessionCreate.AuthFail"
    And the error message is "Authorization not possible, please contact the system administrator."

  Scenario: authenticate with no user and password
    Given I am an agent user with login "" and password ""
    When I login
    Then the response code is 401
    And the response object is Error
    And the error code is "SessionCreate.AuthFail"
    And the error message is "Authorization not possible, please contact the system administrator."

  Scenario: authenticate with sensetive login
    Given I am an agent user with login "Admin" and password "PasswOrd"
    When I login
    Then the response code is 401
    And the response object is Error
    And the error code is "SessionCreate.AuthFail"
    And the error message is "Authorization not possible, please contact the system administrator."

  Scenario: authenticate with sensetive password
    Given I am an agent user with login "admin" and password "PaSswOrd"
    When I login
    Then the response code is 401
    And the response object is Error
    And the error code is "SessionCreate.AuthFail"
    And the error message is "Authorization not possible, please contact the system administrator."






