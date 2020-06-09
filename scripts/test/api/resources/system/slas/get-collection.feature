Feature: GET request to the /system/slas resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing slas
    Given 4 of sla
    When I query the collection of slas
    Then the response code is 200
#    And the response object is SlaCollectionResponse
    When delete all this slas
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing slas with filter
    Given 6 of sla
    When I query the collection of slas
    Then the response code is 200
    When I query the collection of slas with filter of "SLATest4Comment"
    Then the response code is 200
    And the response contains the following items of type SLA
      | Name                 | Comment         |
      | SLATest_4_for_filter | SLATest4Comment |
    When delete all this slas
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing slas with filter contain
    Given 8 of sla
    When I query the collection of slas
    Then the response code is 200
    When I query the collection of slas with filter contains of "4_for"
    Then the response code is 200
    And the response contains the following items of type SLA
      | Name                 | Comment         |
      | SLATest_4_for_filter | SLATest4Comment |
    When delete all this slas
    Then the response code is 204
    And the response has no content

    
  Scenario: get the list of existing slas with limit
    Given 8 of sla
    When I query the collection of slas with a limit of 4
    Then the response code is 200
    And the response contains 4 items of type SLA
    When delete all this slas
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing slas with offset
    Given 8 of sla
    When I query the collection of slas with offset 4
    Then the response code is 200
    And the response contains 4 items of type SLA
    When delete all this slas
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing slas with limit and offset
    Given 8 of sla
    When I query the collection of slas with limit 2 and offset 2
    Then the response code is 200
    And the response contains 2 items of type SLA
    And the response contains the following items of type SLA
      | Name                |
      | SLATest1_for_filter |
    When delete all this slas
    Then the response code is 204
    And the response has no content    
    
   Scenario: get the list of existing slas with sorted
    Given 8 of sla
    When I query the collection of slas with sorted by "SLA.-Names:textual" 
    Then the response code is 200
    And the response contains 8 items of type SLA
    And the response contains the following items of type SLA
      | Name               |
      | SLATest_for_filter |
    When delete all this slas
    Then the response code is 204
    And the response has no content   
    
  Scenario: get the list of existing slas with sorted, limit and offset
    Given 8 of sla
    When I query the collection of slas with sorted by "SLA.-Names:textual" limit 2 and offset 5
    Then the response code is 200
    And the response contains 2 items of type SLA
    When delete all this slas
    Then the response code is 204
    And the response has no content    
    