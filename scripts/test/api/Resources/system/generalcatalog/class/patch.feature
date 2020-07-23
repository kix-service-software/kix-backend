Feature: PATCH request to the /system/generalcatalog/classes/:ClassName resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a generalcatalog class
    When I update this generalcatalog class with ClassName "ITSM::ConfigItem::Computer::Type"
    Then the response code is 200
    When I undo this generalcatalog class with ClassName "Testclass"
#    Then the response code is 200    
#    And the response object is GeneralCatalogClassPatchResponse


