Feature: GET request to the /system/services resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing services
    Given 8 of service
    When I query the collection of services
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    When delete all this services
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing services filtered
    Given 8 of service
    When I query the collection of services
    Then the response code is 200
    When I query the collection of services with filter of "testservice_for_filter"
    Then the response code is 200
    And the response contains the following items of type Service
      | Name                   |
      | testservice_for_filter |
    When delete all this services
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing services filtered contain
    Given 8 of service
    When I query the collection of services
    Then the response code is 200
    When I query the collection of services with filter contains of "for"
    Then the response code is 200
    And the response contains the following items of type Service
      | Name                   |
      | testservice_for_filter |
    When delete all this services
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing services with limit
    Given 8 of service
    When I query the collection of services with a limit of 4
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    And the response contains 4 items of type Service
    When delete all this services
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing services with offset
    Given 8 of service
    Then the response code is 201
    When I query the collection of services with offset 4
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    And the response contains 4 items of type Service
    When delete all this services
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing services with limit and offset
    Given 8 of service
    When I query the collection of services with limit 2 and offset 4
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    And the response contains 2 items of type Service
    When delete all this services
    Then the response code is 204
    And the response has no content    
    
  Scenario: get the list of existing services with sorted
    Given 8 of service
    When I query the collection of services with sorted by "Service.-Names:textual"
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    And the response contains 8 items of type Service
    When delete all this services
    Then the response code is 204
    And the response has no content    
    
  Scenario: get the list of existing services with sorted, limit and offset
    Given 8 of service
    When I query the collection of services with sorted by "Service.-Names:textual" limit 2 and offset 5
    Then the response code is 200
    And the response object is ServiceCollectionResponse
    And the response contains 2 items of type Service
    When delete all this services
    Then the response code is 204
    And the response has no content 
    
    
    
    
    
    
    