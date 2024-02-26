Feature: GET request to the /system/cmdb/classes resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing classes
    When I query the cmdb collection of classes
    Then the response code is 200
    And the response object is ConfigItemClassCollectionResponse

  Scenario: get the list of existing classes filtered
    When I query the cmdb collection of classes with filter of Building
    Then the response code is 200
#    And the response object is ConfigItemClassCollectionResponse
    And the response contains the following items of type ConfigItemClass
      | Name     |
      | Building |

  Scenario: get the list of existing classes with limit
    When I query the cmdb collection of classes with limit 2
    Then the response code is 200
#   And the response object is ConfigItemClassCollectionResponse
    And the response contains 2 items of type "ConfigItemClass"

  Scenario: get the list of existing classes with offset
    When I query the cmdb collection of classes with offset 2
    Then the response code is 200
#    And the response object is ConfigItemClassCollectionResponse
    And the response contains 5 items of type "ConfigItemClass"

  Scenario: get the list of existing classes with limit and offset
    When I query the cmdb collection of classes with limit 2 and offset 2
    Then the response code is 200
    And the response contains 2 items of type "ConfigItemClass"
    And the response contains the following items of type ConfigItemClass
      | Name     |
      | Hardware |
      | Location |
#    And the response object is ConfigItemClassCollectionResponse

  Scenario: get the list of existing classes with sorted
    When I query the cmdb collection of classes with sorted by "ConfigItemClass.-Name:textual"
    Then the response code is 200
    And the response contains 7 items of type "ConfigItemClass"
    And the response contains the following items of type ConfigItemClass
      | Name     |
      | Software |
      | Room     |
      | Network  |
      | Location |
      | Hardware |
      | Computer |
      | Building |
#    And the response object is ConfigItemClassCollectionResponse

  Scenario: get the list of existing classes with sorted, limit and offset
    When I query the cmdb collection of classes with sorted by "ConfigItemClass.-Name:textual" limit 2 and offset 5
    Then the response code is 200
#    And the response object is ConfigItemClassCollectionResponse
    And the response contains 2 items of type "ConfigItemClass"





