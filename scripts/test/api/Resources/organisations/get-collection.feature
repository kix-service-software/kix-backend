 Feature: GET request to the /organisations resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing organisations
    Given 8 of organisations
    When I query the collection of organisations
    Then the response code is 200
#    Then the response object is OrganisationCollectionResponse
    And the response contains the following items of type Organisation
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with filter
    Given 8 of organisations
    When I query the collection of organisations
    When I query the collection of organisation with filter of "K12345678_test_for_filter"
    Then the response code is 200
    And the response contains the following items of type Organisation
      | Number                    |
      | K12345678_test_for_filter |
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with filter contain
    Given 8 of organisations
    When I query the collection of organisations
    When I query the collection of organisation with filter contains of "ambul"
    Then the response code is 200
    And the response contains the following items of type Organisation
      | Number       |
      | abc-ambulanz |
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with limit
    Given 8 of organisations
    When I query the collection of organisations with limit 2
    Then the response code is 200
    And the response contains 2 items of type "Organisation"
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with offset
    Given 8 of organisations
    When I query the collection of organisations with offset 2
    Then the response code is 200
    And the response contains 7 items of type "Organisation"
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with limit and offset
    Given 8 of organisations
    When I query the collection of organisations with limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "Organisation"
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with sorted
    Given 7 of organisations
    When I query the collection of organisations with sorted by "Organisation.-Number:textual"
    Then the response code is 200
    And the response contains 8 items of type "Organisation"
    When delete all this organisations
    Then the response code is 204

  Scenario: get the list of existing organisations with sorted, limit and offset
    Given 8 of organisations
    When I query the collection of organisations with sorted by "Organisation.-Number:textual" limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "Organisation"
    When delete all this organisations
    Then the response code is 204

