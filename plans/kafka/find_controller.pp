plan example::kafka::find_controller (
  Array[String] $targets,
  Boolean $silent = false,
) {
  $controller_metric = 'kafka_controller_kafkacontroller_activecontrollercount'

  $res = choria::run_playbook('choria::tasks::run',
    nodes  => $targets,
    task   => 'example::query_exporter',
    silent => $silent,
    inputs => {
      url     => 'http://127.0.0.1:9080',
      metrics => [ $controller_metric ],
    }
  )

  unless $res.ok {
    fail("Unable to fetch cluster metrics! Failed nodes: ${$res.error_set.hosts.join(',')}")
  }

  # Find controller node
  $controller = $res.reduce([]) |$memo, $r| {
    $out = $r['data']['stdout'].parsejson
    $out['metrics'][$controller_metric] ? {
      '1.0'   => $memo + $r.host,
      default => $memo
    }
  }

  if ($controller.size != 1) {
    fail("There must be exactly 1 controller node in cluster! Nodes found: ${controller.join(',')}")
  }

  $controller
}
