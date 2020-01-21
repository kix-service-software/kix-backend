 Feature: GET request to the /system/generalcatalog resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing generalcatalog items
    When I query the collection of generalcatalog items
    Then the response code is 200
#    And the response object is GeneralCatalogItemCollectionResponse

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items
    Then the response code is 200
    Then the response contains 10 items type GeneralCatalogItem of Class ITSM::ConfigItem::DeploymentState
    And the response contains the following items Class ITSM::ConfigItem::DeploymentState of type GeneralCatalogItem
      | Name        |
      | Expired     |
      | Inactive    |
      | Maintenance |
      | Pilot       |
      | Planned     |
      | Production  |
      | Repair      |
      | Retired     |
      | Review      |
      | Test/QA     |

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items
    Then the response code is 200
    Then the response contains 3 items type GeneralCatalogItem of Class ITSM::Core::IncidentState
    And the response contains the following items Class ITSM::Core::IncidentState of type GeneralCatalogItem
      | Name        |
      | Operational |
      | Warning     |
      | Incident    |


