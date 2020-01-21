Feature: GET request to the /system/cmdb/classes/:ClassID/definitions/:DefinitionID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing definition
    When I get the definition with classid 4 and definitionid 1
    Then the response code is 200    
#    And the attribute "ConfigItemClassDefinition.Name" is "General Information"
#    And the response object is ConfigItemClassDefinitionResponse




    
