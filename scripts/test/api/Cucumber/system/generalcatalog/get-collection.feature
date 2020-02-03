 Feature: GET request to the /system/generalcatalog resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing generalcatalog items
    When I query the collection of generalcatalog items
    Then the response code is 200
#    And the response object is GeneralCatalogItemCollectionResponse

  Scenario: get the list of existing generalcatalog items with filter
    When I query the collection of generalcatalog items with filter of LicenceType
    Then the response code is 200
    And the response contains the following items of type GeneralCatalogItem
      | Class                                   |
      | ITSM::ConfigItem::Software::LicenceType |
      
  Scenario: get the list of existing generalcatalog items with limit
    When I query the collection of generalcatalog items with a limit of 3
    Then the response code is 200
    And the response contains 3 items of type GeneralCatalogItem      
      