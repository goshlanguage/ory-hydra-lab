up:
	kind create cluster --config=kind-config.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

	helm upgrade --install postgres bitnami/postgresql \
			--set global.postgresql.auth.password="LOLCHANGEME2021" \
			--set global.postgresql.auth.username="hydra" \
			--set global.postgresql.auth.database="hydra"

	sleep 5

	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s

	helm upgrade --install hydra-example-idp ory/example-idp \
    --set 'hydraAdminUrl=http://admin.hydra.localhost/' \
    --set 'hydraPublicUrl=http://public.hydra.localhost/' \
    --set 'ingress.enabled=true'

	helm upgrade --install hydra \
    --set 'hydra.config.secrets.system={'$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | base64 | head -c 32)'}' \
    --set 'hydra.config.dsn=postgres://hydra:LOLCHANGEME2021@postgres-postgresql:5432/hydra' \
    --set 'maester.enabled=false' \
    --set 'hydra.autoMigrate=true' \
    --set 'hydra.dangerousForceHttp=true' \
    --set 'hydra.dangerousAllowInsecureRedirectUrls={serve,all}' \
    --set 'hydra.config.urls.self.issuer=http://public.hydra.localhost/' \
    --set 'hydra.config.urls.login=http://example-idp.localhost/login' \
    --set 'hydra.config.urls.consent=http://example-idp.localhost/consent' \
    --set 'hydra.config.urls.logout=http://example-idp.localhost/logout' \
    --set 'hydra.config.strategies.access_token=jwt' \
    --set 'ingress.admin.enabled=true' \
    --set 'ingress.public.enabled=true' \
    --set 'hydra.config.serve.tls.allow_termination_from={127.0.0.1/32,10.0.0.0/8}' \
    ory/hydra

	grep -q "127.0.0.1 public.hydra.localhost" /etc/hosts || \
		sudo -- sh -c "echo \"127.0.0.1 public.hydra.localhost admin.hydra.localhost example-idp.localhost\" >> /etc/hosts";

	kubectl wait \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/name=hydra \
		--timeout=90s

down:
	kind delete cluster --name=hydra-lab
	grep -q "127.0.0.1 public.hydra.localhost" /etc/hosts && \
		sudo -- sh -c "cat /etc/hosts | grep -v hydra > /etc/hosts.new; mv /etc/hosts{.new,}"

clean: down
