# Perform rolling restart of node set
plan example::ssh::restart_nodes (
  Array[String] $targets = [],
  Boolean $silent = false,
  Boolean $noop = false,
  Boolean $reboot = false,
  Array[String] $services = ['ssh'],
) {
  info("Working on nodes: [${targets.join(',')}]")

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

    # No healthcheck here as 'example::util::restart_node' ensures node is accessible
    # and service is running.

    # Give some rest to the cluster
    unless $noop {
      reboot::sleep(30)
    }
  }

  $sorted_targets
}
