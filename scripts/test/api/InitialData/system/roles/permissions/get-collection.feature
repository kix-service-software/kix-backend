Feature: GET request to the /system/roles/:RoleID/permissions resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing permissions of Superuser
    When I query the collection of permissions with roleid 1
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 1 items of type "Permission"
    And the response contains the following items of type Permission
      | Target | Value | TypeID |
      | /*     | 15    | 1      |

  Scenario: get the list of existing permissions of System Admin
    When I query the collection of permissions with roleid 2
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 1 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                                                                                        | Value | TypeID |
      | /system                                                                                                       | 15    | 1      |

  Scenario: get the list of existing permissions of Agent User
    When I query the collection of permissions with roleid 3
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 14 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                                                            | Value | TypeID |
      | /auth                                                                             | 1     | 1      |
      | /session                                                                          | 15    | 1      |
      | /system                                                                           | 2     | 1      |
      | /system/*                                                                         | 0     | 1      |
      | /system/users                                                                     | 2     | 1      |
      | /system/config                                                                    | 2     | 1      |
      | /system/objectdefinitions                                                         | 2     | 1      |
      | /system/valid                                                                     | 2     | 1      |
      | /system/objecticons                                                               | 2     | 1      |
      | /system/generalcatalog                                                            | 2     | 1      |
      | /system/communication                                                             | 2     | 1      |
      | /system/communication/*                                                           | 0     | 1      |
      | /system/communication/notifications                                               | 2     | 1      |
      | /i18n                                                                             | 2     | 1      |

  Scenario: get the list of existing permissions of Ticket Reader
    When I query the collection of permissions with roleid 4
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 17 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                | Value | TypeID |
      | /tickets                              | 2     | 1      |
      | /tickets/*/articles/*/flags           | 15    | 1      |
      | /system/ticket/*                      | 0     | 1      |
      | /system/ticket                        | 2     | 1      |
      | /system/ticket/locks                  | 2     | 1      |
      | /system/ticket/priorities             | 2     | 1      |
      | /system/ticket/queues                 | 2     | 1      |
      | /system/ticket/states                 | 2     | 1      |
      | /system/ticket/types                  | 2     | 1      |
      | /system/ticket/slas                   | 2     | 1      |
      | /system/communication                 | 2     | 1      |
      | /system/communication/*               | 0     | 1      |
      | /system/communication/channels        | 2     | 1      |
      | /system/communication/sendertypes     | 2     | 1      |
      | /system/communication/systemaddresses | 2     | 1      |
      | /links                                | 2     | 1      |

  Scenario: get the list of existing permissions of Ticket Agent
    When I query the collection of permissions with roleid 5
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 18 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                | Value | TypeID |
      | /tickets                              | 15    | 1      |
      | /system/ticket/*                      | 0     | 1      |
      | /system/ticket                        | 2     | 1      |
      | /system/ticket/locks                  | 2     | 1      |
      | /system/ticket/priorities             | 2     | 1      |
      | /system/ticket/queues                 | 2     | 1      |
      | /system/ticket/states                 | 2     | 1      |
      | /system/ticket/types                  | 2     | 1      |
      | /system/ticket/slas                   | 2     | 1      |
      | /system/communication                 | 2     | 1      |
      | /system/communication/*               | 0     | 1      |
      | /system/communication/channels        | 2     | 1      |
      | /system/communication/sendertypes     | 2     | 1      |
      | /system/communication/systemaddresses | 2     | 1      |
      | /organisations                        | 2     | 1      |
      | /contacts                             | 2     | 1      |
      | /links                                | 15    | 1      |

  Scenario: get the list of existing permissions of Ticket Creator
    When I query the collection of permissions with roleid 6
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 7 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                | Value | TypeID |
      | /tickets                              | 1     | 1      |
      | /system/ticket                        | 2     | 1      |
      | /system/communication                 | 2     | 1      |
      | /system/communication/*               | 0     | 1      |
      | /system/communication/channels        | 2     | 1      |
      | /system/communication/sendertypes     | 2     | 1      |
      | /system/communication/systemaddresses | 2     | 1      |

  Scenario: get the list of existing permissions of FAQ Reader
    When I query the collection of permissions with roleid 7
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 7 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                 | Value | TypeID |
      | /system/faq            | 2     | 1      |
      | /system/faq/*          | 0     | 1      |
      | /system/faq/categories | 2     | 1      |
      | /faq                   | 2     | 1      |
      | /faq/*                 | 0     | 1      |
      | /faq/articles          | 2     | 1      |
      | /links                 | 2     | 1      |

  Scenario: get the list of existing permissions of FAQ Editor
    When I query the collection of permissions with roleid 8
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 7 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                 | Value | TypeID |
      | /system/faq            | 2     | 1      |
      | /system/faq/*          | 0     | 1      |
      | /system/faq/categories | 2     | 1      |
      | /faq                   | 15    | 1      |
      | /faq/*                 | 0     | 1      |
      | /faq/articles          | 15    | 1      |
      | /links                 | 15    | 1      |

  Scenario: get the list of existing permissions of Asset Reader
    When I query the collection of permissions with roleid 9
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 7 items of type "Permission"
    And the response contains the following items of type Permission
      | Target               | Value | TypeID |
      | /system/cmdb         | 2     | 1      |
      | /system/cmdb/*       | 0     | 1      |
      | /system/cmdb/classes | 2     | 1      |
      | /cmdb                | 2     | 1      |
      | /cmdb/*              | 0     | 1      |
      | /cmdb/configitems    | 2     | 1      |
      | /links               | 2     | 1      |

  Scenario: get the list of existing permissions of Asset Maintainer
    When I query the collection of permissions with roleid 10
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 7 items of type "Permission"
    And the response contains the following items of type Permission
      | Target               | Value | TypeID |
      | /system/cmdb         | 2     | 1      |
      | /system/cmdb/*       | 0     | 1      |
      | /system/cmdb/classes | 2     | 1      |
      | /cmdb                | 15    | 1      |
      | /cmdb/*              | 0     | 1      |
      | /cmdb/configitems    | 15    | 1      |
      | /links               | 15    | 1      |

  Scenario: get the list of existing permissions of Customer Reader
    When I query the collection of permissions with roleid 11
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 2 items of type "Permission"
    And the response contains the following items of type Permission
      | Target         | Value | TypeID |
      | /organisations | 2     | 1      |
      | /contacts      | 2     | 1      |

  Scenario: get the list of existing permissions of Customer Manager
    When I query the collection of permissions with roleid 12
    Then the response code is 200
 #   And the response object is PermissionCollectionResponse
    And the response contains 2 items of type "Permission"
    And the response contains the following items of type Permission
      | Target         | Value | TypeID |
      | /organisations | 15    | 1      |
      | /contacts      | 15    | 1      |

  Scenario: get the list of existing permissions of Customer
    When I query the collection of permissions with roleid 13
    Then the response code is 200
#    And the response object is PermissionCollectionResponse
    And the response contains 43 items of type "Permission"
    And the response contains the following items of type Permission
      | Target                                                                                                                                    | Value | TypeID |
      | /auth                                                                                                                                     | 1     | 1      |
      | /cmdb                                                                                                                                     | 2     | 1      |
      | /contacts                                                                                                                                 | 3     | 1      |
      | /faq                                                                                                                                      | 2     | 1      |
      | /faq/*                                                                                                                                    | 0     | 1      |
      | /faq/articles                                                                                                                             | 2     | 1      |
      | /faq/articles/*{FAQArticle.CustomerVisible NE 1}                                                                                          | 0     | 2      |
      | /faq/articles/*/votes                                                                                                                     | 3     | 1      |
      | /i18n                                                                                                                                     | 2     | 1      |
      | /links                                                                                                                                    | 2     | 1      |
      | /session                                                                                                                                  | 15    | 1      |
      | /system                                                                                                                                   | 2     | 1      |
      | /system/*                                                                                                                                 | 0     | 1      |
      | /system/cmdb                                                                                                                              | 2     | 1      |
      | /system/cmdb/*                                                                                                                            | 0     | 1      |
      | /system/cmdb/classes                                                                                                                      | 2     | 1      |
      | /system/communication                                                                                                                     | 2     | 1      |
      | /system/communication/*                                                                                                                   | 0     | 1      |
      | /system/communication/channels                                                                                                            | 2     | 1      |
      | /system/communication/notifications                                                                                                       | 2     | 1      |
      | /system/communication/sendertypes                                                                                                         | 2     | 1      |
      | /system/communication/systemaddresses                                                                                                     | 2     | 1      |
      | /system/faq                                                                                                                               | 2     | 1      |
      | /system/faq/*                                                                                                                             | 0     | 1      |
      | /system/faq/categories                                                                                                                    | 2     | 1      |
      | /system/ticket                                                                                                                            | 2     | 1      |
      | /system/ticket/templates/*{TicketTemplate.CustomerVisible NE 1}                                                                           | 0     | 2      |
      | /system/users                                                                                                                             | 2     | 1      |
      | /tickets                                                                                                                                  | 3     | 1      |
      | /tickets/*                                                                                                                                | 6     | 1      |
      | /tickets{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}              | 0     | 2      |
      | /tickets/*{Ticket.ContactID NE $CurrentUser.Contact.ID && Ticket.OrganisationID NE $CurrentUser.Contact.PrimaryOrganisationID}            | 0     | 2      |
      | /tickets/*{Ticket.[Age,Articles,Changed,ContactID,Created,CreateTimeUnix,DynamicFields,OrganisationID,PriorityID,QueueID,StateID,TypeID]} | 2     | 3      |
      | /tickets/*/articles                                                                                                                       | 3     | 1      |
      | /tickets/*/articles/*                                                                                                                     | 2     | 1      |
      | /tickets/*/articles/*{Article.CustomerVisible NE 1}                                                                                       | 0     | 2      |
      | /tickets/*/articles/*{Article.[*,!Bcc,!BccRealname]}                                                                                      | 2     | 3      |
      | /tickets/*/articles/*/flags                                                                                                               | 3     | 1      |
      | /system/config                                                                                                                            | 2     | 1      |
      | /system/config/*                                                                                                                          | 2     | 1      |
      | /system/config{SysConfigOption.AccessLevel NE external}                                                                                   | 0     | 2      |
      | /system/config/*{SysConfigOption.AccessLevel NE external}                                                                                 | 0     | 2      |