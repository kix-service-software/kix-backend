Feature: GET request to the /watchers/:WatcherID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get a collection of existing ticket watchers
    Given a ticket
    Then the response code is 201
    When I create a watcher
      | UserID |
      | 1      |
    When I get a collection of watchers
    Then the response code is 200
    When I delete this watcher
    Then the response code is 204
    And the response has no content
    When I delete this ticket
    Then the response code is 204
    And the response has no content 





    
