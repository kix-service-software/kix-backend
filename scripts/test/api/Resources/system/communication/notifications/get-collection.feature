 Feature: GET request to the /system/communication/notifications resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing notifications
    When I query the collection of notifications
    Then the response code is 200
    Then the response object is NotificationCollectionResponse

  Scenario: get the list of existing notifications filtered
    When I query the collection of notifications with filter of "Responsible Assignment"
    Then the response code is 200
    And the response contains the following items of type Notification
      | Name                           |
      | Agent - Responsible Assignment |

  Scenario: get the list of existing notifications filtered contain
    When I query the collection of notifications with filter contains of "Own"
    Then the response code is 200
    And the response contains the following items of type Notification
      | Name                     |
      | Agent - Owner Assignment |

  Scenario: get the list of existing notifications with limit
    When I query the collection of notifications with a limit of 1
    Then the response code is 200
    And the response contains 1 items of type "Notification"

  Scenario: get the list of existing notifications with sorted
    When I query the collection of notifications sorted by "Notification.-Name:textual"
    Then the response code is 200
    And the response contains 12 items of type "Notification"
    And the response contains the following items of type Notification
      | Name                                     |
      | Customer - New Ticket Receipt            |
      | Customer - Follow Up Rejection           |
      | Agent - Ticket Move Notification         |
      | Agent - Responsible Assignment           |
      | Agent - Reminder (if unlocked)           |
      | Agent - Reminder (if locked)             |
      | Agent - Owner Assignment                 |
      | Agent - New Ticket Notification          |
      | Agent - New Note Notification            |
      | Agent - Lock Timeout                     |
      | Agent - FUP Notification (if unlocked)   |
      | Agent - FUP Notification (if locked)     |

  Scenario: get the list of existing notifications with sorted and limit
    When I query the collection of notifications sorted by "Notification.-Name:textual" and with a limit of 4
    Then the response code is 200
    And the response contains 4 items of type "Notification"
    And the response contains the following items of type Notification
      | Name                             |
      | Customer - New Ticket Receipt    |
      | Customer - Follow Up Rejection   |
      | Agent - Ticket Move Notification |
      | Agent - Responsible Assignment   |

  Scenario: get the list of existing notifications with offset
    When I query the collection of notifications with offset of 4
    Then the response code is 200
    And the response contains 8 items of type "Notification"
