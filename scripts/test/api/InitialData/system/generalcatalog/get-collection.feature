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

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items
    Then the response code is 200
    Then the response contains 9 items type GeneralCatalogItem of Class ITSM::ConfigItem::Software::Type
    And the response contains the following items Class ITSM::ConfigItem::Software::Type of type GeneralCatalogItem
      | Name               |
      | Client Application |
      | Middleware         |
      | Server Application |
      | Client OS          |
      | Server OS          |
      | Admin Tool         |
      | User Tool          |
      | Embedded           |
      | Other              |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items
     Then the response code is 200
     Then the response contains 2 items type GeneralCatalogItem of Class ITSM::ConfigItem::YesNo
     And the response contains the following items Class ITSM::ConfigItem::YesNo of type GeneralCatalogItem
       | Name |
       | Yes  |
       | No   |

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items
    Then the response code is 200
    Then the response contains 14 items type GeneralCatalogItem of Class ITSM::ConfigItem::Software::LicenceType
    And the response contains the following items Class ITSM::ConfigItem::Software::LicenceType of type GeneralCatalogItem
      | Name               |
      | Single Licence     |
      | Per User           |
      | Concurrent Users   |
      | Per Processor      |
      | Per Server         |
      | Per Node           |
      | Volume Licence     |
      | Enterprise Licence |
      | Developer Licence  |
      | Demo               |
      | Time Restricted    |
      | Freeware           |
      | Unlimited          |
      | Open Source        |

  Scenario: check is the existing generalcatalog are consistent with the delivery defaults
    When I query the collection of generalcatalog items
    Then the response code is 200
    Then the response contains 5 items type GeneralCatalogItem of Class ITSM::ConfigItem::Network::Type
    And the response contains the following items Class ITSM::ConfigItem::Network::Type of type GeneralCatalogItem
      | Name  |
      | LAN   |
      | WLAN  |
      | Telco |
      | GSM   |
      | Other |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items
     Then the response code is 200
     Then the response contains 9 items type GeneralCatalogItem of Class ITSM::ConfigItem::Location::Type
     And the response contains the following items Class ITSM::ConfigItem::Location::Type of type GeneralCatalogItem
       | Name        |
       | Building    |
       | Office      |
       | Floor       |
       | Room        |
       | Rack        |
       | Workplace   |
       | Outlet      |
       | IT Facility |
       | Other       |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items
     Then the response code is 200
     Then the response contains 16 items type GeneralCatalogItem of Class ITSM::ConfigItem::Hardware::Type
     And the response contains the following items Class ITSM::ConfigItem::Hardware::Type of type GeneralCatalogItem
       | Name              |
       | Monitor           |
       | Printer           |
       | Switch            |
       | Router            |
       | WLAN Access Point |
       | Security Device   |
       | Backup Device     |
       | Mouse             |
       | Keyboard          |
       | Camera            |
       | Beamer            |
       | Modem             |
       | USB Device        |
       | Docking Station   |
       | Scanner           |
       | Other             |

   Scenario: check is the existing generalcatalog are consistent with the delivery defaults
     When I query the collection of generalcatalog items
     Then the response code is 200
     Then the response contains 5 items type GeneralCatalogItem of Class ITSM::ConfigItem::Computer::Type
     And the response contains the following items Class ITSM::ConfigItem::Computer::Type of type GeneralCatalogItem
       | Name    |
       | Desktop |
       | Phone   |
       | Server  |
       | Other   |
       | Laptop  |






