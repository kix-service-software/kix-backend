 Feature: GET request to the /system/objectdefinitions/:ObjectType resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing objectdefinition
    When I get the objectdefinition with ObjectType "FAQArticle" 
    Then the response code is 200
    And the attribute "ObjectDefinition.Object" is "FAQArticle"

