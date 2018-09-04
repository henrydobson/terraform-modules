# Terraform AWS Modules & Projects Monorepo

## Acknowledgement

Thank you to [Concrete Media Ltd.](https://www.concreteplatform.com) for allowing me to open source some of the Terraform work we developed for their microservice infrastructure on Kubernetes and common services.

## Modules

* [Registries](https://www.terraform.io/docs/modules/sources.html)


```
module "example" {
  source = "git::https://gitlab.example.net/infrastructure/example.git?ref=v1"
}
```

### License

Apache 2 Licensed. See LICENSE for full details.