Feature: GET request to the /tickets/TicketID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing ticket
    Given a ticket
    When I get this ticket
    Then the response code is 200
    When I delete this ticket
    Then the response code is 204
    And the response has no content

  Scenario: get an existing ticket with article
    Given a ticket with one article
    Then the response code is 201
    When I get this ticket with include article
    Then the response code is 200
    And the response contains the following article attributes
      | From            | To                    | Channel | SenderType | ToRealname            | Subject    |
      | root@nomail.org | contact222@nomail.org | note    | agent      | contact222@nomail.org | d  fsd fds | 
    When I delete this ticket
    Then the response code is 204
    And the response has no content
    
