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
    When I query the collection of generalcatalog items "ITSM::ConfigItem::DeploymentState"
    Then the response code is 200
    And the response contains 10 items of type "GeneralCatalogItem"
    And the response contains the following items of type GeneralCatalogItem
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
    When I query the collection of generalcatalog items "ITSM::Core::IncidentState"
    Then the response code is 200
    And the response contains 3 items of type "GeneralCatalogItem"
    And the response contains the following items of type GeneralCatalogItem
      | Name        |
      | Incident    |
      | Operational |
      | Warning            |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items "ITSM::ConfigItem::Software::Type"
    Then the response code is 200
    And the response contains 9 items of type "GeneralCatalogItem"
    And the response contains the following items of type GeneralCatalogItem
      | Name               |
      | Admin Tool         |
      | Client Application |
      | Client OS          |
      | Embedded           |
      | Middleware         |
      | Other              |
      | Server Application |
      | Server OS          |
      | User Tool          |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items "ITSM::ConfigItem::YesNo"
     Then the response code is 200
     And the response contains 2 items of type "GeneralCatalogItem"
     And the response contains the following items of type GeneralCatalogItem
       | Name |
       | No   |
       | Yes  |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items "ITSM::ConfigItem::Software::LicenceType"
    Then the response code is 200
    And the response contains 14 items of type "GeneralCatalogItem"
    And the response contains the following items of type GeneralCatalogItem
      | Name               |
      | Concurrent Users   |
      | Demo               |
      | Developer Licence  |
      | Enterprise Licence |
      | Freeware           |
      | Open Source        |
      | Per Node           |
      | Per Processor      |
      | Per Server         |
      | Per User           |
      | Single Licence     |
      | Time Restricted    |
      | Unlimited          |
      | Volume Licence     |

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items "ITSM::ConfigItem::Network::Type"
    Then the response code is 200
    And the response contains 5 items of type "GeneralCatalogItem"
    And the response contains the following items of type GeneralCatalogItem
      | Name  |
      | GSM   |
      | LAN   |
      | Other |
      | Telco |
      | WLAN  |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items "ITSM::ConfigItem::Location::Type"
     Then the response code is 200
     And the response contains 9 items of type "GeneralCatalogItem"
     And the response contains the following items of type GeneralCatalogItem
       | Name        |
       | Building    |
       | Floor       |
       | IT Facility |
       | Office      |
       | Other       |
       | Outlet      |
       | Rack        |
       | Room        |
       | Workplace   |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items "ITSM::ConfigItem::Hardware::Type"
     Then the response code is 200
     And the response contains 16 items of type "GeneralCatalogItem"
     And the response contains the following items of type GeneralCatalogItem
       | Name              |
       | Backup Device     |
       | Beamer            |
       | Camera            |
       | Docking Station   |
       | Keyboard          |
       | Modem             |
       | Monitor           |
       | Mouse             |
       | Other             |
       | Printer           |
       | Router            |
       | Scanner           |
       | Security Device   |
       | Switch            |
       | USB Device        |
       | WLAN Access Point |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items "ITSM::ConfigItem::Computer::Type"
     Then the response code is 200
     Then the response contains 5 items type GeneralCatalogItem of Class ITSM::ConfigItem::Computer::Type
     And the response contains the following items of type GeneralCatalogItem
       | Name    |
       | Desktop |
       | Laptop  |
       | Other   |
       | Phone   |
       | Server  |








