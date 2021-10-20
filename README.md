# Ory Hydra

Ory Hydra is an Oauth 2.0 provider. To understand Hydra, one must understand Oauth 2.0. Trying to understand Hydra without understanding Oauth 2.0 would be similar to trying to understand Calculus without a fundamental understanding of algebra. As such, let's start with a short, and inadequate summation of Oauth 2.0.

Oauth 2.0 is defined in great length in [RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749), stating:

> The OAuth 2.0 authorization framework enables a third-party application to obtain limited access to an HTTP service, either on behalf of a resource owner by orchestrating an approval interaction between the resource owner and the HTTP service, or by allowing the third-party application to obtain access on its own behalf.

Some specific terminology is good to know, as you'll find them in any Oauth 2.0 supporting material, and are as follows:

> - Resource Owner: Entity that can grant access to a protected resource. Typically, this is the end-user.
> - Client: Application requesting access to a protected resource on behalf of the Resource Owner.
> - Resource Server: Server hosting the protected resources. This is the API you want to access.
> - Authorization Server: Server that authenticates the Resource Owner and issues Access Tokens after getting proper authorization. In this case, Auth0.
> - User Agent: Agent used by the Resource Owner to interact with the Client (for example, a browser or a native application).

- https://auth0.com/docs/authorization/flows/which-oauth-2-0-flow-should-i-use


The way it works is rather well visualized in the [RFC's Protocol Flow segment](https://datatracker.ietf.org/doc/html/rfc6749#section-1.2):

```
     +--------+                               +---------------+
     |        |--(A)- Authorization Request ->|   Resource    |
     |        |                               |     Owner     |
     |        |<-(B)-- Authorization Grant ---|               |
     |        |                               +---------------+
     |        |
     |        |                               +---------------+
     |        |--(C)-- Authorization Grant -->| Authorization |
     | Client |                               |     Server    |
     |        |<-(D)----- Access Token -------|               |
     |        |                               +---------------+
     |        |
     |        |                               +---------------+
     |        |--(E)----- Access Token ------>|    Resource   |
     |        |                               |     Server    |
     |        |<-(F)--- Protected Resource ---|               |
     +--------+                               +---------------+
```

Let's follow this flow more or less with Hydra.

First, bring up a local kubernetes cluster with Hydra and it's dependencies by running `make up`. This does require escalated permissions in order to poke some DNS overrides into `/etc/hosts`.

Now to start, we must create an Oauth2 client, which will allow us to interact with the Oauth 2 provider, `hydra`:

```sh
hydra clients create \
    --endpoint http://admin.hydra.localhost/ \
    --id my-client \
    --secret secret \
    --grant-types client_credentials
```

With this client, we can interact with the Oauth 2.0 provider. Let's step through the `client credentials grant`, step B in the diagram above, so we can interact with hydra on behalf of the client we just created. What is a client credentials grant?

> The Client Credentials grant type is used by clients to obtain an access token outside of the context of a user. This is typically used by clients to access resources about themselves rather than to access a user's resources.
- [https://oauth.net/2/grant-types/client-credentials/](https://oauth.net/2/grant-types/client-credentials/)

```
hydra token client \
    --endpoint http://public.hydra.localhost/ \
    --client-id my-client \
    --client-secret secret
```

You can inspect this issued token one of two ways:
- Paste it's contents into https://jwt.io
- Run `hydra token introspect --endpoint http://admin.hydra.localhost/ <token>`

The output of this should look similar to:

```
{
    "active": true,
    "aud": [],
    "client_id": "my-client",
    "exp": 1634741942,
    "iat": 1634738342,
    "iss": "http://public.hydra.localhost/",
    "nbf": 1634738342,
    "sub": "my-client",
    "token_type": "Bearer",
    "token_use": "access_token"
}
```

Each of these fields are important, so if you are new to JWT, it would be valuable to [read the intro to jwt tokens](https://jwt.io/introduction) for a deeper understanding.

Next, let's perform the `OAuth 2.0 Authorization Code Grant`.

> An Oauth 2.0 Authorization Code Grant is used by public clients to exchange an authorization code for an access token
- [https://oauth.net/2/grant-types/authorization-code/](https://oauth.net/2/grant-types/authorization-code/)

In order to be able to do this, we have to create a client that has the grant-type `authorization_code` to do it. We will also include the `refresh_token` grant so that this client can get subsequent tokens after the initial access token expires. You can read more about this process [here](https://www.oauth.com/oauth2-servers/making-authenticated-requests/refreshing-an-access-token/)

```
hydra clients create \
    --endpoint http://admin.hydra.localhost/ \
    --audience http://public.hydra.localhost/ \
    --id auth-code-client \
    --secret secret \
    --grant-types client_credentials,authorization_code,refresh_token \
    --response-types code,id_token \
    --token-endpoint-auth-method client_secret_post \
    --scope openid,offline
```

We can see the list of our created hydra clients now by running `hydra clients list \    --endpoint http://admin.hydra.localhost`:

```
hydra clients list --endpoint http://admin.hydra.localhost
|    CLIENT ID     | NAME | RESPONSE TYPES |             SCOPE             |         REDIRECT URIS          |           GRANT TYPES            | TOKEN ENDPOINT AUTH METHOD |
|------------------|------|----------------|-------------------------------|--------------------------------|----------------------------------|----------------------------|
| auth-code-client |      | code,id_token  | openid offline                | http://127.0.0.1:5555/callback | authorization_code,refresh_token | client_secret_basic        |
| my-client        |      | code           | offline_access offline openid |                                | client_credentials               | client_secret_basic        |
```

Now let's put our client to work. This repo contains a small go project that leverages the oidc (OpenID connect)

## Clean Up

To clean up this lab, you can use the Make target, `make down`.

# Resources

This lab is a derivative work of Hydra's own "5 minute tutorial":
https://www.ory.sh/hydra/docs/next/5min-tutorial/

You can find more resources on hydra in their upstream docs:
https://www.ory.sh/hydra/docs/

This documentation was put together from referencing the following resources:

- [RFC6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [Oauth.net](https://oauth.net/)
- [Oauth.com])https://oauth.com/)
- [Auth0.com docs](https://auth0.com/docs)
- [JWT.io](https://jwt.io)

The `Makefile` leverages the upstream hydra chart. You can find the chart and its associated values here:
https://github.com/ory/k8s/blob/master/helm/charts/hydra/
