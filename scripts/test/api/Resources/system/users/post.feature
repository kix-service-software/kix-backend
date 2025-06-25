Feature: POST request to the /system/users resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a user
     When added a user
     Then the response code is 201
     Then the response object is UserPostPatchResponse

  Scenario: added a user with roles
     When added a user with roles
     Then the response code is 201
#     Then the response object is UserPostPatchResponse

  Scenario: added a user with no login
    When added a user with no login
    Then the response code is 400

  Scenario: added a user with the same login
    When added a user with the same login
    Then the response code is 201
    When added a user with the same login
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"
    And the error message is "Cannot create user. Another user with same login already exists."

