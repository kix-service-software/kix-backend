Feature: GET request to the /system/cmdb/classes resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing class
    When I get the configitem class with ID 4
    Then the response code is 200
    And the response object is ConfigItemClassResponse
    And the attribute "ConfigItemClass.Name" is "Computer"



    
