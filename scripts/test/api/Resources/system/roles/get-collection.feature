
Feature: GET request to the /system/roles resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing roles
    When I query the collection of roles
    Then the response code is 200
    And the response object is RoleCollectionResponse

  Scenario: get the list of existing roles with filter
    When I query the collection of roles with filter of "Customer Manager"
    Then the response code is 200
    And the response contains the following items of type Role
      | Name             |
      | Customer Manager |

  Scenario: get the list of existing roles with filter contain
    When I query the collection of roles with filter contains of "FAQ E"
    Then the response code is 200
    And the response contains the following items of type Role
      | Name       |
      | FAQ Editor |

  Scenario: get the list of existing roles with limit
    When I query the collection of roles with a limit of 2
    Then the response code is 200
    And the response contains 2 items of type "Role"

  Scenario: get the list of existing roles with offset
    When I query the collection of roles with offset 2
    Then the response code is 200
    And the response contains 18 items of type "Role"

  Scenario: get the list of existing roles with limit and offset
    When I query the collection of roles with limit 2 and offset 4
    Then the response code is 200
    And the response contains 2 items of type "Role"

  Scenario: get the list of existing roles with sorted
    When I query the collection of roles with sorted by "Role.-Name:textual"
    Then the response code is 200
    And the response contains 20 items of type "Role"
    And the response contains the following items of type Role
      | Name                         |
      | Webform Ticket Creator       |
      | Ticket Reader                |
      | Ticket Agent (Servicedesk)   |
      | Ticket Agent Base Permission |
      | Ticket Agent                 |
      | Textmodule Admin             |
      | System Admin                 |
      | Superuser                    |
      | Report User                  |
      | Report Manager               |
      | FAQ Reader                   |
      | FAQ Editor                   |
      | FAQ Admin                    |
      | Customer Reader              |
      | Customer Manager             |
      | Customer                     |
      | Asset Reader                 |
      | Asset Maintainer             |
      | Agent User                   |


  Scenario: get the list of existing roles with sorted, limit and offset
    When I query the collection of roles with sorted by "Role.-Name:textual" limit 2 and offset 5
    Then the response code is 200
    And the response contains 2 items of type "Role"
    And the response contains the following items of type Role
      | Name           |
      | Report User    |
      | Report Manager |

