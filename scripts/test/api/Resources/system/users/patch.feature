Feature: PATCH request to the /system/users/:UserID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a user
    Given a user
    When I update this user
    Then the response code is 200
    And the response object is UserPostPatchResponse
#    When I delete this user
#    Then the response code is 204

  Scenario: changed password with policy
    Given a user
    When I update this user pw
    Then the response code is 200
    When I update this user pw with incorrect pw
    Then the response code is 400
    And the error code is "Validator.Failed"
    And the error message is "Password has to be at least 6 characters long. It needs at least 2 upper case, 2 lower case and 1 digit."

