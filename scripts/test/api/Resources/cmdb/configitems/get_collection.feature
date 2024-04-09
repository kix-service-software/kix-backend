Feature: GET request to the /cmdb/configitems resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing configitems
    Given a configitem
#    Then the response content
    When I query the cmdb collection of configitems
    Then the response code is 200
#       Then the response content is
#    And the response object is ConfigItemCollectionResponse
    When I delete this configitem
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with filter
    Given 4 of configitems
#    Then the response content
    When I query the cmdb collection of configitems
#    Then the response content 
    Then the response code is 200
    When I query the cmdb collection of configitems with filter of DeplStateID 17
#    Then the response content
    Then the response code is 200
    And the response contains the following items of type ConfigItem
      | CurDeplStateID |
      | 17             |
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with filter in
    Given 4 of configitems
    When I query the cmdb collection of configitems with filter in of DeplStateID 16
    Then the response code is 200
    And the response contains the following items of type ConfigItem
      | CurDeplStateID | Class    |
      | 16             | Computer |
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with limit
    Given 8 of configitems
    When I query the cmdb collection of configitems with limit 4
    Then the response code is 200
    And the response contains 4 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with offset
    Given 8 of configitems
    When I query the cmdb collection of configitems with offset 4
    Then the response code is 200
    And the response contains 4 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with limit and offset
    Given 8 of configitems
    When I query the cmdb collection of configitems with limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems with sorted
    Given 8 of configitems
    When I query the cmdb collection of configitems with sorted by "ConfigItem.-CreateTime:datetime"
    Then the response code is 200
    And the response contains 8 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems searchlimit
    Given 80 of configitems
    When I query the cmdb collection of configitems 55 searchlimit
    Then the response code is 200
    And the response contains 55 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing configitems searchlimit object
    Given 80 of configitems
    When I query the cmdb collection of configitems 35 searchlimit object
    Then the response code is 200
    And the response contains 35 items of type "ConfigItem"
    When delete all of configitems
    Then the response code is 204
    And the response has no content















