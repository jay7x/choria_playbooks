# Perform ES nodes rolling restart
# https://www.elastic.co/guide/en/elasticsearch/reference/current/restart-cluster.html#restart-cluster-rolling
plan example::elasticsearch::restart_nodes (
  Array[String] $targets = [],
  Boolean $silent = false,
  Boolean $noop = false,
  Boolean $reboot = false,
  Array[String] $services = ['elasticsearch'],
  Boolean $synced_flush = true,
  Integer $healthcheck_tries = 30,
  Optional[String] $cluster_name = undef,
) {
  unless $cluster_name {
    fail('Please specify $cluster_name!')
  }

  info("Working on nodes: [${targets.join(',')}]")

  # Check cluster state
  $ready = choria::run_playbook('example::elasticsearch::check_health',
    cluster_name => $cluster_name,
    targets      => $targets,
    silent       => $silent,
  )
  unless $ready {
    fail('Cluster is not healthy!')
  }

  $sorted_targets = $targets.sort

  # Restart every node in order
  $sorted_targets.each |$target| {

    # Disable shard allocation & flush
    unless choria::run_playbook('example::elasticsearch::restart_node_pre',
      target       => $target,
      synced_flush => $synced_flush,
      silent       => $silent,
    ) {
      fail('Failed to disable shard allocation/perform flush')
    }

    choria::run_playbook('example::util::restart_node',
      target   => $target,
      services => $services,
      silent   => $silent,
      reboot   => $reboot,
      noop     => $noop,
    )

    # Enable shard allocation
    unless choria::run_playbook('example::elasticsearch::restart_node_post',
      target => $target,
      silent => $silent,
    ) {
      fail('Failed to enable shard allocation! Please check cluster settings!')
    }

    # Check cluster state
    unless choria::run_playbook('example::elasticsearch::check_health',
      cluster_name => $cluster_name,
      targets      => $sorted_targets,
      tries        => $healthcheck_tries,
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
