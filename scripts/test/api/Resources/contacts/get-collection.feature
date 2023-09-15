 Feature: GET request to the /contacts resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing contacts
    Given a contact 
    When I query the collection of contacts 
    Then the response code is 200
#    And the response object is ContactCollectionResponse

  Scenario: get the list of existing contacts with filter
    Given a organisation
    Given 4 of contact 
    When I query the collection of contacts with filter of "mamu_test_filter@example.org"
    Then the response code is 200
    And the response contains the following items of type Contact
        | Email                        |
        | mamu_test_filter@example.org |
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When I delete this organisation
    Then the response code is 204
    And the response has no content

  Scenario: get the list of existing contacts with filter and
    Given 6 of organisations
    Given 4 of contact with diffrent organisation
    When I query the collection of contacts
    When I query the collection of contacts with filter of Firstname "Tom" and Lastname "Meier"
    Then the response code is 200
    And the response contains the following items of type Contact
        | Email                          |
        | tmeier_test_filter@example.org |
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing contacts with limit
    Given 6 of organisations
    Given 4 of contact with diffrent organisation
    When I query the collection of contacts with limit 2 
    Then the response code is 200
    And the response contains 2 items of type "Contact"
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing contacts with offset
    Given 4 of organisations
    Given 4 of contact with diffrent organisation
    When I query the collection of contacts
    When I query the collection of contacts with offset 2 
    Then the response code is 200
    And the response contains 3 items of type "Contact"
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content
    
  Scenario: get the list of existing contacts with limit and offset
    Given 8 of organisations
    Given 8 of contact with diffrent organisation
    When I query the collection of contacts
    When I query the collection of contacts with limit 2 and offset 4 
    Then the response code is 200
    And the response contains 2 items of type "Contact"
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content    

  Scenario: get the list of existing contacts with sorted
    Given 8 of organisations
    Given 8 of contact with diffrent organisation
    When I query the collection of contacts
    When I query the collection of contacts with sorted by "Contact.-Firstname:textual"
    Then the response code is 200
    And the response contains 9 items of type "Contact"
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content      
    
  Scenario: get the list of existing contacts with sorted, limit and offset
    Given 8 of organisations
    Given 8 of contact with diffrent organisation
    When I query the collection of contacts
    When I query the collection of contacts with sorted by "Contact.-Firstname:textual" limit 2 and offset 1
    Then the response code is 200
    And the response contains 2 items of type "Contact"
    When delete all this contacts
    Then the response code is 204
    And the response has no content
    When delete all this organisations
    Then the response code is 204
    And the response has no content

   Scenario: get the list of existing contacts with include User
     Given a organisation
     Given a contact
     When I query the collection of contacts with include User
     Then the response code is 200
     When delete all this contacts
     Then the response code is 204
     And the response has no content
     When delete all this organisations
     Then the response code is 204
     And the response has no content
       
    