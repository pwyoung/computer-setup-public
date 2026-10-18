# Minikube Driver Tradeoffs

## NodePort

- **`none` driver**: Direct `curl localhost:<nodePort>` works — the port binds on the host NIC
- **`docker` driver**: Direct access does not work — the port binds inside the Docker container, not on the host. Requires `minikube service <name>` or `minikube service <name> --url` to open a tunnel on a random host port

## LoadBalancer

Both drivers require `minikube tunnel` running in a separate terminal. Once the tunnel is up, the service gets `EXTERNAL-IP: 127.0.0.1` and traffic routes through correctly.

## Summary

| | `none` driver | `docker` driver |
|---|---|---|
| NodePort direct | `curl localhost:<nodePort>` ✓ | needs `minikube service` |
| LoadBalancer | `minikube tunnel` | `minikube tunnel` |
| Run as | root (sudo) | regular user |
| Host interference | modifies host network/processes | isolated in container |

## Recommendation

Use the `none` driver if your primary use case is testing services via NodePort without extra commands — it gives true localhost access and is simpler for local development.

Use the `docker` driver if host isolation matters more than convenience — K8s processes run inside a container rather than directly on the host.
