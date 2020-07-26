# Choria.io example playbooks

Choria offers the amazing ability to write playbooks in Puppet DSL. Here are few examples on how to use Choria to reboot some clusters.

Examples included for
  * Cassandra
  * Elasticsearch
  * Kafka
  * OpenTSDB
  * RabbitMQ
  * SSH

Every playbook requires a list of nodes to proceed with. Ideally there should be a discovery playbook to wire plans together. It's usually very infrastructure-specific though. So you should write it for your infra yourself.

Healthchecks are using prometheus exporters usually even if service provides HTTP REST API. The only exception here is OpenTSDB as there was no good prometheus exporter available. Main reason behind this is to have the same vision of the service state as your monitoring system has.

Playbooks perform healthchecks using either Bolt tasks supplied under `tasks` directory or [MCollective HTTP Query agent](https://github.com/jay7x/jay7x-mcollective_agent_query) (OpenTSDB).

To use Bolt tasks please keep in mind at present Choria will only consult your `production` environment for tasks (as mentioned in Choria [docs](https://choria.io/docs/tasks/usage/))

To use MCollective agent please install it from [the module on Puppet Forge](https://forge.puppet.com/jay7x/mcollective_agent_query).
