# IP address of target eZLO system for test/dev
IP=192.168.178.109
# name of plugin
PID=VeraBridge

# Rule to make remote path, only needed once
mkdir: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) mkdir -p /home/data/custom_plugins/$(PID)

# Rule to test-compile firmware, used for simple syntax error detect so we don't send up obvious brokenness.
comp:
	luac -p scripts/*.lua
	luac -p scripts/utils/*.lua

# Rule to stop the plugin and copy the code to the LinuxEdge
copy: 
	scp -i ~/.ssh/ezlo_edge -r *.json scripts root@$(IP):/home/data/custom_plugins/$(PID)/

# Rule to stop the plugin
unreg: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.unregister $(PID)
	
# Rule to restart the plugin
reg: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.register $(PID)

# Rule to uninstall the plugin
uninstall: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.uninstall $(PID)

# restart all daemons
restart_all: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) /etc/init.d/firmware  restart

# Restart lua daemon
restart: 
	ssh -i ~/.ssh/ezlo_edge root@$(IP) /etc/init.d/ha-luad  restart
	
# Rule to send code up and restart the plugin
all: comp unreg copy reg
