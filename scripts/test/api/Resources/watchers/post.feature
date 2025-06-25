Feature: POST request to the /watchers resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a watcher
    Given a ticket
    When I create a watcher
      | UserID |
      | 1      |
    Then the response code is 201
    And the response object is WatcherPostResponse
    When I delete this watcher
    Then the response code is 204
    And the response has no content
    When I delete this ticket
    Then the response code is 204
    And the response has no content

  Scenario: I create a watcher fail attribute object
    When I create a watcher fail attribute object
    Then the response code is 409

  Scenario: I create a watcher fail attribute objectid
    When I create a watcher fail attribute objectid
    Then the response code is 409
    
  Scenario: I create a watcher fail attribute userid
    When I create a watcher fail attribute userid
    Then the response code is 400















