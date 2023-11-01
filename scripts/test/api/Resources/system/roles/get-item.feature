Feature: GET request to the /system/roles/:RoleID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing role
    Given a role with Name "the new stats role GET"
    When I get this role
    Then the response code is 200
#    And the response object is RoleResponse
    And the attribute "Role.Name" is "the new stats role GET"
    When I delete this role
    Then the response code is 204    
