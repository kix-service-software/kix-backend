Feature: POST request to the /system/generalcatalog resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a generalcatalog
    When I create a generalcatalog item
    Then the response code is 201
#    Then the response object is GeneralCatalogItemPostPatchResponse
    When I delete this generalcatalog item
    Then the response code is 204

  Scenario: create a generalcatalog without class
    When I create a generalcatalog item without class
    Then the response code is 400
    And the response object is Error
    And the error code is "BadRequest"
    And the error message is "Required parameter GeneralCatalogItem::Name is missing or undefined!"
