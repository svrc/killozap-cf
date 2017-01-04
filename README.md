Destroys (with extreme prejudice) consul or etcd cluster persistent state for a given cf deployment for when those clusters have lost quorum.   

Assumes the PCF convention where etcd server jobs have the pattern "etcd_server" and diego BBS have "diego_database" job patterns.
Also assumes that you can't predict which consul agent thinks its the leader, so it's best to nuke them all.

**Usage:  killozap.sh [etcd|bbs|consul|ripley]**

**etcd** argument will 
* find all etcd_server jobs and etcd processes in a bosh deployment 
* monit stop etcd 
* rm -rf /var/vcap/store/etcd 
* restart all etcd servers.

**consul** argument will 
* find all consul_agent processes in a bosh deployment (across ALL jobs)
* monit stop consul_agent 
* rm -rf /var/vcap/store/consul_agent 
* restart all consul_agent processes

**bbs** argument will
* find all diego_database etcd processes in a bosh deployment
* monit stop etcd
* rm -rf /var/vcap/store/etcd
* restart all etcd processes

**ripley** argument will nuke the site from orbit (aka. all of the above).

*"The designer of the gun had clearly not been instructed to beat about the bush. 'Make it evil,' he'd been told. 'Make it totally clear that this gun has a right end and a wrong end. Make it totally clear to anyone standing at the wrong end that things are going badly for them. If that means sticking all sort of spikes and prongs and blackened bits all over it, then so be it. This is not a gun for hanging over the fireplace or sticking in the umbrella stand, it is a gun for going out and making people miserable with.'"* - Douglas Adams


