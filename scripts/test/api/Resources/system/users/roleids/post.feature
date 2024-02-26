Feature: POST request to the /system/users/:UserID/roleids resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a user roleid
     When added a user roleid with UserID 1
     Then the response code is 201
     Then the response object is UserRoleIDPostResponse
     When I delete this user roleid with UserID 1
     Then the response code is 204

