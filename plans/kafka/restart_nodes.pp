# Perform Kafka nodes rolling restart
plan example::kafka::restart_nodes (
  Array[String] $targets = [],
  Boolean $silent = false,
  Boolean $noop = false,
  Boolean $reboot = false,
  Array[String] $services = ['kafka'],
  Integer $healthcheck_tries = 30,
) {
  info("Working on nodes: [${targets.join(',')}]")

  # Check cluster state
  unless choria::run_playbook('example::kafka::check_health',
    targets => $targets,
    silent  => $silent,
  ) {
    fail('Cluster is not healthy!')
  }

  # Find controller node
  $controller = choria::run_playbook('example::kafka::find_controller',
    targets => $targets,
    silent  => $silent,
  )

  info("Controller node is ${controller}")

  # Move cluster controller to the end of the list
  $sorted_targets = $targets.sort - $controller + $controller

  # Restart every node in order
  $sorted_targets.each |$target| {
    choria::run_playbook('example::util::restart_node',
      target   => $target,
      services => $services,
      silent   => $silent,
      reboot   => $reboot,
      noop     => $noop,
    )

    # Check cluster state
    unless choria::run_playbook('example::kafka::check_health',
      targets => $sorted_targets,
      tries   => $healthcheck_tries,
      silent  => $silent,
    ) {
      fail("Node ${node} is failed! Please check cluster health!")
    }

    # Give some rest to the cluster
    unless $noop {
      reboot::sleep(30)
    }
  }

  $sorted_targets
}
