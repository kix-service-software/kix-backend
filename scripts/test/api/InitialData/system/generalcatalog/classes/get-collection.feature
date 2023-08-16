 Feature: GET request to the /system/generalcatalog resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing generalcatalog classes
    When I query the collection of generalcatalog class
    Then the response code is 200
    Then the response contains 10 items type of GeneralCatalogClass
    And response contains the following items type GeneralCatalogClass
      | Class                                   |
      | ITSM::ConfigItem::Class                 |
      | ITSM::ConfigItem::Computer::Type        |
      | ITSM::ConfigItem::DeploymentState       |
      | ITSM::ConfigItem::Hardware::Type        |
      | ITSM::ConfigItem::Location::Type        |
      | ITSM::ConfigItem::Network::Type         |
      | ITSM::ConfigItem::Software::LicenceType |
      | ITSM::ConfigItem::Software::Type        |
      | ITSM::ConfigItem::YesNo                 |
      | ITSM::Core::IncidentState               |



