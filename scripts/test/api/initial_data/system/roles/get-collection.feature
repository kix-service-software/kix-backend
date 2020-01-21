Feature: GET request to the /system/roles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing roles
    When I query the collection of roles
    Then the response code is 200
    And the response object is RoleCollectionResponse
    And the response contains 12 items of type "Role"
    And the response contains the following items of type Role
      | Name              | Comment                                                                                                                                                        | ValidID |
      | Superuser         | full permissions on everything (CRUD on resource /*)                                                                                                           | 1       |
      | Asset Maintainer  | same as Asset-Reader, but additionally  allows to create new or update any existing asset entry and allows to CREATE, UPDATE, DELETE links                     | 1       |
      | Customer Reader   | allows to read information of any organization or contact and allows to READ links                                                                             | 1       |
      | Customer Manager  | same as Customer Reader, but additionally allows to create new or update any existing contact or organization entry and allows to CREATE, UPDATE, DELETE links | 1       |
      | System Admin      | allows to change/edit any system configuration found in the Admin-Module, requires Agent-User role though in order to log in the system                        | 1       |
      | Agent User        | allows to login in both frontend- and backend application but does not grant any further permissions                                                           | 1       |
      | Ticket Reader     | allows to read any ticket in any queue and allows to READ links                                                                                                | 1       |
      | Ticket Agent      | same as Ticket Reader, but additionally allows to create new or edit any existing ticket and allows to CREATE, UPDATE, DELETE links                            | 1       |
      | Ticket Creator    | allows to read any information required to create a ticket (queues, types, priorities, etc.), allows to create new tickets and allows to CREATE links          | 1       |
      | FAQ Reader        | allows to read any FAQ article in any FAQ category and allows to READ links                                                                                    | 1       |
      | FAQ Editor        | same as FAQ Reader, but additionally allows to create new or edit any existing FAQ article and allows to CREATE, UPDATE, DELETE links                          | 1       |
      | Asset Reader      | allows to read any asset information in any asset class and allows to READ links                                                                               | 1       |
