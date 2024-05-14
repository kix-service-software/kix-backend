 Feature: GET request to the /system/communication/notifications resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

#   Scenario Outline: get the list of existing notifications
#     When I query the collection of notifications
#     Then the response code is 200
#     Then the response content is
#     Then the notifications output is "<Name>"

#     Examples:
#       | Name                                     |
#       | Agent - New Ticket Notification          |
#       | Agent - Reminder (if unlocked)           |
#       | Customer - New Ticket Receipt            |
#       | Customer - Follow Up Rejection           |
#       | Agent - FUP Notification (if unlocked)   |
#       | Agent - FUP Notification (if locked)     |
#       | Agent - Lock Timeout                     |
#       | Agent - Owner Assignment                 |
#       | Agent - Responsible Assignment           |
#       | Agent - New Note Notification            |
#       | Agent - Ticket Move Notification         |
#       | Agent - Reminder (if locked)             |


  Scenario: get the list of existing notifications
    When I query the collection of notifications
    Then the response code is 200
    Then the response contains 12 items of type "Notification"
    And the response contains the following items of type Notification
      | Name                                     | ValidID |
      | Agent - New Ticket Notification          | 1       |
      | Agent - Reminder (if unlocked)           | 1       |
      | Customer - New Ticket Receipt            | 1       |
      | Customer - Follow Up Rejection           | 2       |
      | Agent - FUP Notification (if unlocked)   | 1       |
      | Agent - FUP Notification (if locked)     | 1       |
      | Agent - Lock Timeout                     | 1       |
      | Agent - Owner Assignment                 | 1       |
      | Agent - Responsible Assignment           | 1       |
      | Agent - New Note Notification            | 1       |
      | Agent - Ticket Move Notification         | 1       |
      | Agent - Reminder (if locked)             | 1       |

  Scenario: get the list of Watcher Notifications
    When I get this notification id 10
    Then the response code is 200
    And items of "Recipients"
      | Attribut              |
      | AgentMyQueues         |
      | AgentOwner            |
      | AgentReadPermissions  |
      | AgentResponsible      |
      | AgentWatcher          |
      | AgentWritePermissions |

   Scenario: get the list of Watcher Notifications
     When I get this notification id 3
     Then the response code is 200
     And items of "Recipients"
       | Attribut              |
       | AgentOwner            |
       | AgentResponsible      |
       | AgentWatcher          |

   Scenario: get the list of Watcher Notifications
     When I get this notification id 4
     Then the response code is 200
     And items of "Recipients"
       | Attribut              |
       | AgentOwner            |
       | AgentWatcher          |

   Scenario: get the list of Watcher Notifications
     When I get this notification id 5
     Then the response code is 200
     And items of "Recipients"
       | Attribut              |
       | AgentOwner            |
       | AgentWatcher          |

   Scenario: get the list of Watcher Notifications
     When I get this notification id 7
     Then the response code is 200
     And items of "Recipients"
       | Attribut              |
       | AgentOwner            |
       | AgentResponsible      |
       | AgentWatcher          |

   Scenario: get the list of Watcher Notifications
     When I get this notification id 9
     Then the response code is 200
     And items of "Recipients"
       | Attribut              |
       | AgentOwner            |
       | AgentResponsible      |
       | AgentWatcher          |



















