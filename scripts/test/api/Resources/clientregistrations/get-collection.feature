 Feature: GET request to the /clientregistration resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing clientregistration
    Given 8 of clientregistrations
    When I query the collection of clientregistration
    Then the response code is 200
#    Then the response object is ClientRegistrationCollectionResponse
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with filter
    Given 8 of clientregistrations
    When I query the collection of clientregistration with filter of "KIX-Frontend_Test_Filter"
    Then the response code is 200
    And the response contains the following items of type ClientRegistration
      | ClientID                 |
      | KIX-Frontend_Test_Filter |
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with filter contain
    Given 8 of clientregistrations
    When I query the collection of clientregistration with filter contains of "end_T"
    Then the response code is 200
    And the response contains the following items of type ClientRegistration
      | ClientID                 |
      | KIX-Frontend_Test_Filter |
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with filter end
    Given 8 of clientregistrations
    When I query the collection of clientregistration with filter end of "ilter"
    Then the response code is 200
    And the response contains the following items of type ClientRegistration
      | ClientID                 |
      | KIX-Frontend_Test_Filter |
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with limit
    Given 8 of clientregistrations
    When I query the collection of clientregistration with limit 4
    Then the response code is 200
    And the response contains 4 items of type "ClientRegistration"
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with offset
    Given 8 of clientregistrations
    When I query the collection of clientregistration with offset 2
    Then the response code is 200
    And the response contains 7 items of type "ClientRegistration"
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with limit and offset
    Given 8 of clientregistrations
    When I query the collection of clientregistration with limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "ClientRegistration"
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing clientregistration with sorted, limit and offset
    Given 8 of clientregistrations
    When I query the collection of clientregistration with sorted by "ClientRegistration.-ClientID:textual" limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "ClientRegistration"
    When delete all this clientregistrations
    Then the response code is 204
    And the response has no content






