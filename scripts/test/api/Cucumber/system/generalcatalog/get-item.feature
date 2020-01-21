 Feature: GET request to the /system/generalcatalog/:GeneralCatalogItemID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing generalcatalog item
    Given a generalcatalog item
    Then the response code is 201
    When I get this generalcatalog item
    Then the response code is 200
#    And the response object is GeneralCatalogItemResponse 
    And the attribute "GeneralCatalogItem.Class" is "ITSM::ConfigItem::Computer::Type"
    When I delete this generalcatalog item
    Then the response code is 204
    And the response has no content