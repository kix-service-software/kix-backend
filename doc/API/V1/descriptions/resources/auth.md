##### Supported POST-Requests

* Auth-Request
    * Creates a session token
    * Needs authorization data
        * UserLogin and Password (Local login via DB oder LDAP)
        * NegotiationToken (SSO via Kerberos)
        * state and code (OIDC)
* PreAuth-Request
    * Creates data required for following authentification
        * i.e. RedirectURL for OIDC
    * Needs type of PreAuth and type specific data