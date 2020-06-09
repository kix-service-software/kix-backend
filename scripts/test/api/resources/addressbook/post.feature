Feature: POST request /addressbook resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a addressbook
     When added a addressbook
     Then the response code is 201
     When delete all this addressbooks
     Then the response code is 204

  Scenario: I create a addressbook with a address that already exists
    When added a addressbook with address "AddressTest@local.de"
    Then the response code is 201
    When added a addressbook with address "AddressTest@local.de"
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"    
    And the error message is "Cannot create address book entry. Another address with same email address already exists."
    When delete all this addressbooks
    Then the response code is 204


     
     
     
     
     