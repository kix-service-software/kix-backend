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
