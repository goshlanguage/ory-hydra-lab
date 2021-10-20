// Package cmd is the package that manages the cli for datapipe
package cmd

import (
	"context"
	"fmt"
	"net/url"
	"os"

	"github.com/spf13/cobra"
	"golang.org/x/oauth2/clientcredentials"
)

var (
	clientID     string
	clientSecret string
	endpoint     string
)

var rootCmd = &cobra.Command{
	Use: "ory-hydra-lab",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&clientID, "client-id", "auth-code-client", "The client id you want to auth with")
	rootCmd.PersistentFlags().StringVar(&clientSecret, "client-secret", "secret", "The client secret you want to auth with")
	rootCmd.PersistentFlags().StringVar(&endpoint, "endpoint", "http://public.hydra.localhost", "The url of your oauth provider")

	getToken(clientID, clientSecret, endpoint)
}

func getToken(clientID, clientSecret, endpoint string) {
	oauthConfig := clientcredentials.Config{
		ClientID:       clientID,
		ClientSecret:   clientSecret,
		TokenURL:       endpoint + "/oauth2/token",
		EndpointParams: url.Values{"audience": {endpoint}},
	}

	token, err := oauthConfig.Token(context.TODO())
	if err != nil {
		panic(err)
	}

	fmt.Println("Successfully acquired a token:", token.AccessToken)
}
