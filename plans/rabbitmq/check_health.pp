# Check RabbitMQ cluster health
# Relying on https://github.com/kbudde/rabbitmq_exporter exporter
# FIXME Add https://github.com/rabbitmq/rabbitmq-prometheus support for RabbitMQ > 3.8
# Expecting rabbitmq_running == $targets.size
plan example::rabbitmq::check_health (
  Array[String] $targets,
  Integer $tries = 40,
  Integer $try_sleep = 15,
  Boolean $silent = false,
  String $exporter_url = 'http://127.0.0.1:9419/metrics',
) {
  $health_metric = 'rabbitmq_running'

  # Every server return every node's stats (so we have NxN results)
  $good_number = $targets.size * $targets.size

  Integer[1, $tries].each |$try| {
    # Get cluster stats
    $res = choria::task(
      action     => 'query.exporter',
      nodes      => $targets,
      silent     => $silent,
      fail_ok    => true,
      properties => {
        url     => $exporter_url,
        metrics => [ $health_metric ],
      },
    )

    # Ensure every node can see every other node (NxN)
    $good_servers = $res.reduce(0) |$memo, $r| {
      $ngs = $r['data']['metrics'].reduce(0) |$mm, $m| {
        $mm + ceiling(Integer($m[1]))
      }
      $memo + $ngs
    }

    if $good_servers == $good_number {
      return true
    }

    warning("Cluster is not OK. Retrying... (${try}/${tries})!")

    if $try < $tries {
      reboot::sleep($try_sleep)
    }
  }
  return false
}
