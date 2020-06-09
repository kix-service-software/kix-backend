 Feature: GET request to the /addressbook resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing addressbook
    Given 4 of addressbooks
    When I query the collection of addressbook 
    Then the response code is 200
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content


  Scenario: get the list of existing addressbook with filter one
    Given 4 of addressbooks
    When I query the collection of addressbook with filter of test_for
    Then the response code is 200
    And the response contains the following items of type Address
      | EmailAddress             |
      | test_for_filter@test.org |
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing addressbook with filter contain
    Given 6 of addressbooks
    When I query the collection of addressbook
    When I query the collection of addressbook with filter contains of Muster
    Then the response code is 200
    And the response contains the following items of type Address
      | EmailAddress                 |
      | Thomas.Mustertester@test.org |
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing addressbook with filter firstname
    Given 6 of addressbooks
    When I query the collection of addressbook
    When I query the collection of addressbook with filter and of Thomas
    Then the response code is 200
    And the response contains the following items of type Address
      | EmailAddress                 |
      | Thomas.Tester@test.org       |
      | Thomas.Mustertester@test.org |
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing addressbook with limit
    Given 8 of addressbooks
    When I query the collection of addressbook with limit 4 
    Then the response code is 200
    And the response contains 4 items of type Address
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing addressbook with offset
    Given 8 of addressbooks
    When I query the collection of addressbook with offset 4 
    Then the response code is 200
    And the response contains 4 items of type Address
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing addressbook with limit and offset
    Given 8 of addressbooks
    When I query the collection of addressbook with limit 2 and offset 4 
    Then the response code is 200
    And the response contains 2 items of type Address
    And the response contains the following items of type Address
      | EmailAddress                 |      
      | Thomas.Mustertester@test.org |
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content    
    
   Scenario: get the list of existing addressbook with sorted
    Given 8 of addressbooks
    When I query the collection of addressbook with sorted by "Address.-EmailAddress:textual" 
    Then the response code is 200
    And the response contains 8 items of type Address
    And the response contains the following items of type Address
      | EmailAddress                 |
      | Thomas.Tester@test.org       |
      | Thomas.Mustertester@test.org |
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
    
   Scenario: get the list of existing addressbook with sorted, limit and offset
    Given 8 of addressbooks
    When I query the collection of addressbook with sorted by "Address.-EmailAddress:textual" limit 2 and offset 5
    Then the response code is 200
    And the response contains 2 items of type Address
    When delete all this addressbooks
    Then the response code is 204
    And the response has no content
      