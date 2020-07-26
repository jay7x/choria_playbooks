# Perform OpenTSDB nodes rolling restart
# So far we're just restarting nodes 1-by-1 in order
plan example::opentsdb::restart_nodes (
  Array[String] $targets = [],
  Boolean $silent = false,
  Boolean $noop = false,
  Boolean $reboot = false,
  Array[String] $services = ['opentsdb'],
) {
  info("Working on nodes: [${targets.join(',')}]")

  # Check cluster state
  unless choria::run_playbook('example::opentsdb::check_health',
    targets      => $targets,
    silent       => $silent,
  ) {
    fail('Cluster is not healthy!')
  }

  $sorted_targets = $targets.sort

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
    unless choria::run_playbook('example::opentsdb::check_health',
      targets      => $sorted_targets,
      silent       => $silent,
    ) {
      fail("Node ${node} is failed! Please check cluster health!")
    }

    # Temporary safeguard
    unless $noop {
      reboot::sleep(30)
    }
  }

  $sorted_targets
}
