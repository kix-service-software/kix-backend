 Feature: GET request to the /faq/articles resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of initial faq articles
    When I query the collection of faq articles
    Then the response code is 200
    Then the response contains 8 items of type "FAQArticle"
    And the response contains the following items of type FAQArticle
      | Title                                          |
      | Allgemeine Hinweise zum Arbeiten mit KIX 18    |
      | General information on how to work with KIX 18 |
      | Wie suche ich in KIX 18?                       |
      | How to search in KIX 18?                       |    
      | Ausgewählte Ticketfunktionen                   |
      | Selected Ticket Features                       | 
      | Neues Ticket                                   |
      | New Ticket                                     |         